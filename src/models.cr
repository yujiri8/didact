class Comment
  DB.mapping({
    id:            Int64,
    name:          String,
    body:          String,
    article_path:  String,
    article_title: String,
    ip:            String?,
    ua:            String?,
    time_added:    Time,
    time_changed:  Time?,
    reply_to:      Int64?,
    user_id:       Int64?,
  })
  alias CommentJson = Int64 | String | Bool | Time | Nil | Array(Hash(String, CommentJson))

  def initialize(@name, @body, @article_path, @article_title, @ip,
                 @ua, @time_added, @time_changed = nil, @reply_to = nil, @user_id = nil, @id = 0.to_i64)
  end

  def dict(db, user_id = nil, raw = false, recursion = 5) : Hash(String, CommentJson)
    cmt = {
      "id"           => @id,
      "name"         => @name,
      "reply_to"     => @reply_to,
      "body"         => (raw ? @body : Util.markdown @body.as(String)),
      "time_added"   => @time_added,
      "time_changed" => @time_changed,
      "replies"      => recursion > 0 ? get_comments(db, "reply_to = ? ORDER BY time_added DESC", @id).to_a.map &.dict(
        db, user_id: user_id, raw: raw, recursion: recursion - 1) : db.scalar("SELECT count(id) FROM comments WHERE reply_to = ?", @id).as(Int64),
    } of String => CommentJson
    # If a user is provided, attach whether they're subscribed to the comment and whether it's theirs.
    if !user_id.nil?
      cmt["sub"] = get_sub_status(db, user_id, @id)
      cmt["owned"] = user_id == @user_id
    end
    cmt
  end

  def summary_dict
    {
      "id"            => @id,
      "name"          => @name,
      "article_title" => @article_title,
      "link"          => "#{@article_path}?c=#{@id}#comment-section",
      "time_added"    => @time_added,
    }
  end

  # Raises exception if the comment is invalid.
  def validate(db)
    raise UserErr.new(400, "You need a name") if @name == ""
    raise UserErr.new(400, "Your name can't be longer than 30 characters") if @name.size > 30
    raise UserErr.new(400, "That name is taken by a registered user.") \
       if (name_owner = get_users(db, "name = ?", @name)[0]?) && name_owner.id != @user_id
    # One can be missing, but not both.
    raise UserErr.new(400) if @reply_to.nil? && @article_path.nil?
  end
end

class User
  DB.mapping({
    id:            Int64,
    email:         String,
    auth:          String,
    name:          String?,
    pw:            String?,
    disable_reset: Bool,
    admin:         Bool,
    autosub:       Bool,
    sub_site:      Bool,
  })

  def initialize(@email, @auth, @name = nil, @pw = nil, @disable_reset = false,
                 @admin = false, @autosub = false, @sub_site = false, @id = 0.to_i64)
  end
end
