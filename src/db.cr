COMMENT_FIELDS = "name, body, article_path, article_title, ip, ua, time_added, time_changed, reply_to, user_id"
USER_FIELDS    = "email, auth, name, pw, disable_reset, admin, autosub, sub_site"
WORD_FIELDS    = "name, meaning, notes, time_added, time_changed"

def get_comments(db, where, *args)
  db.query_all "SELECT id, #{COMMENT_FIELDS} FROM comments WHERE #{where}", *args, as: Comment
end

def get_comment(db, where, *args)
  db.query_one "SELECT id, #{COMMENT_FIELDS} FROM comments WHERE #{where} LIMIT 1", *args, as: Comment
end

def add_comment(db, comment)
  comment.id = db.exec("INSERT INTO comments (#{COMMENT_FIELDS}) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    comment.name, comment.body, comment.article_path, comment.article_title, comment.ip, comment.ua,
    comment.time_added, comment.time_changed, comment.reply_to, comment.user_id,
  ).last_insert_id
  comment
end

def change_comment(db, comment)
  db.exec "UPDATE comments SET (#{COMMENT_FIELDS}) = (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) WHERE id = ?",
    comment.name, comment.body, comment.article_path, comment.article_title, comment.ip, comment.ua,
    comment.time_added, comment.time_changed, comment.reply_to, comment.user_id, comment.id
end

def get_users(db, where, *args)
  db.query_all "SELECT id, #{USER_FIELDS} FROM users WHERE #{where}", *args, as: User
end

def get_user(db, where, *args)
  db.query_one "SELECT id, #{USER_FIELDS} FROM users WHERE #{where} LIMIT 1", *args, as: User
end

def add_user(db, user)
  user.id = db.exec("INSERT INTO users (#{USER_FIELDS}) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    user.email, user.auth, user.name, user.pw, user.disable_reset, user.admin, user.autosub, user.sub_site,
  ).last_insert_id
  user
end

def change_user(db, user)
  db.exec "UPDATE users SET (#{USER_FIELDS}) = (?, ?, ?, ?, ?, ?, ?, ?) WHERE id = ?",
    user.email, user.auth, user.name, user.pw, user.disable_reset, user.admin, user.autosub, user.sub_site, user.id
end

# Gets the subscription status for a given user and comment.
def get_sub_status(db, user : Int64, comment : Int64) : Bool | Nil
  db.scalar("SELECT sub FROM subs WHERE user_id = ? AND comment_id = ?", user, comment).as(Int64) != 0
rescue DB::NoResultsError
  nil
end

def set_sub_status(db, user : Int64, comment : Int64, sub : Bool?)
  # Delete any existing subscription to avoid duplicates.
  db.exec("DELETE FROM subs WHERE user_id = ? AND comment_id = ?", user, comment)
  # Now create a new one if appropriate.
  db.exec("INSERT INTO subs (user_id, comment_id, sub) VALUES (?, ?, ?)", user, comment, sub) if !sub.nil?
end

# Returns the email addresses and subscribe/ignore flag of users subscribed to a comment.
def get_comment_subs(db, comment : Int64)
  db.query_all "SELECT users.email, subs.sub FROM subs JOIN users ON subs.user_id = users.id WHERE comment_id = ?",
    comment, as: {String, Bool}
end

# Returns the email addresses of users subscribed to an article.
def get_article_subs(db, path : String)
  db.query_all "SELECT email FROM article_subs JOIN users ON article_subs.user_id = users.id" +
               " WHERE article_subs.path = ?", path, as: String
end

def set_article_sub(db, user : Int64, path : String, sub : Bool)
  begin
    title = Util.get_article_title(path)
  rescue
    raise UserErr.new 404, "No such article"
  end
  path.chomp("index") if path.ends_with? "/index"
  # Delete any existing subscription to avoid duplicates.
  db.exec("DELETE FROM article_subs WHERE user_id = ? AND path = ?", user, path)
  db.exec("INSERT INTO article_subs (user_id, path, title) VALUES (?, ?, ?)", user, path, title) if sub
end

# Returns the comments a user is subscribed to.
def get_user_comment_subs(db, user : Int64)
  subs = [] of Hash(String, Bool | Hash(String, Int64 | String | Time))
  db.query_each "SELECT subs.sub, comments.id, name, article_title, article_path, time_added FROM subs
      JOIN comments ON subs.comment_id = comments.id WHERE subs.user_id = ?", user do |rs|
    subs << {"sub" => rs.read(Bool), "comment" => Comment.new(
      id: rs.read(Int64),
      name: rs.read(String),
      article_title: rs.read(String),
      article_path: rs.read(String),
      time_added: rs.read(Time),
      body: "", ip: nil, ua: nil,
    ).summary_dict}
  end
  subs
end

# Returns the comments a user is subscribed to.
def get_user_article_subs(db, user : Int64)
  subs = [] of Hash(String, String)
  db.query_each "SELECT title, path FROM article_subs WHERE user_id = ?", user do |rs|
    subs << {"title" => rs.read(String), "path" => rs.read(String)}
  end
  subs
end

def get_words(db, where, args)
  words = [] of Word
  # There's some bizzarre use-after-free bug that happens with nested queries, so finish the first one
  # before we go for the translations and tags.
  db.query_each "SELECT id, #{WORD_FIELDS} FROM words WHERE #{where}", args: args do |rs|
    word = Word.new(
      id: rs.read(Int64),
      name: rs.read(String),
      meaning: rs.read(String),
      notes: rs.read(String),
      time_added: rs.read(Time),
      time_changed: rs.read(Time),
    )
    words << word
  end
  words.each do |word|
    word.translations = db.query_all "SELECT translation FROM translations WHERE word_id = ?", word.id, as: String
    word.tags = db.query_all "SELECT tag FROM tags WHERE word_id = ?", word.id, as: String
  end
  words
end

def get_word(db, where, *args)
  results = get_words db, where, *args
  results[0]
rescue IndexError
  raise UserErr.new 404
end

def add_word(db, word)
  db.transaction do |tx|
    word.id = tx.connection.exec("INSERT INTO words (#{WORD_FIELDS}) VALUES (?, ?, ?, ?, ?)",
      word.name, word.meaning, word.notes, word.time_added, word.time_changed).last_insert_id
    save_translations_and_tags tx.connection, word
    word
  end
end

def change_word(db, word)
  db.transaction do |tx|
    tx.connection.exec "UPDATE words SET (#{WORD_FIELDS}) = (?, ?, ?, ?, ?) WHERE id = ?",
      word.name, word.meaning, word.notes, word.time_added, word.time_changed, word.id
    tx.connection.exec "DELETE from translations where word_id = ?", word.id
    tx.connection.exec "DELETE from tags where word_id = ?", word.id
    save_translations_and_tags tx.connection, word
  end
end

def save_translations_and_tags(db, word)
  word.translations.each do |t|
    db.exec("INSERT INTO translations (word_id, translation) VALUES (?, ?)", word.id, t)
  end
  word.tags.each do |t|
    db.exec("INSERT INTO tags (word_id, tag) VALUES (?, ?)", word.id, t)
  end
end
