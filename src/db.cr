COMMENT_FIELDS = "name, body, article_path, article_title, ip, ua, time_added, time_changed, reply_to, user_id"

def get_comments(db, where, *args)
  comments = [] of Comment
  db.query "SELECT id, #{COMMENT_FIELDS} FROM comments WHERE #{where}", args: args.to_a do |rs|
    rs.each do
      comments << Comment.new(
        id: rs.read(Int64),
        name: rs.read(String),
        body: rs.read(String),
        article_path: rs.read(String),
        article_title: rs.read(String),
        ip: rs.read(String?),
        ua: rs.read(String?),
        time_added: rs.read(Time),
        time_changed: rs.read(Time?),
        reply_to: rs.read(Int64?),
        user_id: rs.read(Int64?),
      )
    end
  end
  comments
end

def get_comment(db, where, *args)
  get_comments(db, where, *args)[0]
rescue IndexError
  raise UserErr.new 404
end

def add_comment(db, comment)
  comment.id = (db.scalar "INSERT INTO (#{COMMENT_FIELDS}) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id", args: [
        comment.name, comment.body, comment.article_path, comment.article_title, comment.ip, comment.ua,
        comment.time_added, comment.time_changed, comment.reply_to, comment.user_id,
  ]).as(Int64)
  comment
end
def change_comment(db, comment)
  db.exec "UPDATE comments SET (#{COMMENT_FIELDS}) = (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) WHERE id = ?", args: [
        comment.name, comment.body, comment.article_path, comment.article_title, comment.ip, comment.ua,
        comment.time_added, comment.time_changed, comment.reply_to, comment.user_id, comment.id,
  ]
  comment
end

USER_FIELDS = "email, auth, name, pw, disable_reset, admin, autosub, sub_site"

def get_users(db, where, *args)
  users = [] of User
  db.query "SELECT id, #{USER_FIELDS} FROM users WHERE #{where}", args: args.to_a do |rs|
    rs.each do
      users << User.new(
        id: rs.read(Int64),
        email: rs.read(String),
        auth: rs.read(String),
        name: rs.read(String),
        pw: rs.read(String),
        disable_reset: rs.read(Bool),
        admin: rs.read(Bool),
        autosub: rs.read(Bool),
        sub_site: rs.read(Bool),
      )
    end
  end
  users
end

def get_user(db, where, *args)
  get_users(db, where, *args)[0]
rescue IndexError
  raise UserErr.new 404
end

def add_user(db, user)
  user.id = (db.scalar "INSERT INTO users (#{USER_FIELDS}) VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id", args: [
        user.email, user.auth, user.name, user.pw, user.disable_reset, user.admin, user.autosub, user.sub_site,
  ]).as(Int64)
  user
end

def change_user(db, user)
  db.exec "UPDATE users SET (#{USER_FIELDS}) = (?, ?, ?, ?, ?, ?, ?, ?) WHERE id = ?", args: [
    user.email, user.auth, user.name, user.pw, user.disable_reset, user.admin, user.autosub, user.sub_site, user.id,
  ]
end


# Gets the subscription status for a given user and comment.
def get_sub_status(db, user : Int64, comment : Int64) : Bool | Nil
  db.scalar("SELECT sub FROM subs WHERE user_id = ? AND comment_id = ?", user, comment).as(Int64) != 0
rescue DB::NoResultsError
  nil
end

def set_sub_status(db, user : Int64, comment : Int64, sub : Bool?)
  # Delete any existing subscription to avoid duplicates.
  db.scalar("DELETE FROM subs WHERE user_id = ? AND comment_id = ?", user, comment)
  # Now create a new one if appropriate.
  db.exec("INSERT INTO subs (user_id, comment_id, sub) VALUES (?, ?, ?)", user, comment, sub) if !sub.nil?
end

# Returns the email addresses and subscribe/ignore flag of users subscribed to a comment.
def get_comment_subs(db, comment : Int64)
  subs = [] of {String, Bool}
  db.query("SELECT users.email, subs.sub FROM subs JOIN users ON subs.user_id = users.id WHERE comment_id = ?",
      comment) do |rs|
    rs.each do
      subs << {rs.read(String), rs.read(Bool)}
    end
  end
  subs
end

# Returns the email addresses of users subscribed to an article.
def get_article_subs(db, path : String)
  subs = [] of String
  db.query("SELECT email FROM article_subs JOIN users ON article_subs.user_id = users.id WHERE article_subs.path = ?",
      path) do |rs|
    rs.each do
      subs << rs.read(String)
    end
  end
  subs
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
    db.exec("INSERT INTO article_subs (user_id, path, title) VALUES (?, ?, ?)", args: [user, path, title]) if sub
end

# Returns the comments a user is subscribed to.
def get_user_comment_subs(db, user : Int64)
  subs = [] of Hash(String, Bool | Hash(String, Int64 | String | Time))
  db.query("SELECT subs.sub, comments.id, name, article_title, article_path, time_added FROM subs
      JOIN comments ON subs.comment_id = comments.id WHERE subs.user_id = ?", user) do |rs|
    rs.each do
      subs << {"sub" => rs.read(Bool), "comment" => Comment.new(
        id: rs.read(Int64),
        name: rs.read(String),
        article_title: rs.read(String),
        article_path: rs.read(String),
        time_added: rs.read(Time),
        body: "", ip: nil, ua: nil,
      ).summary_dict}
    end
  end
  subs
end

# Returns the comments a user is subscribed to.
def get_user_article_subs(db, user : Int64)
  subs = [] of Hash(String, String)
  db.query("SELECT title, path FROM article_subs WHERE user_id = ?", user) do |rs|
    rs.each do
      subs << {"title" => rs.read(String), "path" => rs.read(String)}
    end
  end
  subs
end
