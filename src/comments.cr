get "/comments" do |env|
  cmts = if id = env.params.query["id"]?.try &.to_i?
    get_comments(env.db, "id = ?", id)
  elsif article_path = env.params.query["article_path"]?
    get_comments(env.db, "article_path == ? AND reply_to IS NULL ORDER BY time_added DESC", article_path)
  else
    raise UserErr.new 400
  end
  resp = {
    "comments" => cmts.map &.dict(env.db, user_id: env.user.try &.id, raw: env.params.query["raw"]?),
  } of String => Array(Hash(String, Comment::CommentJson)) | Bool
  resp["article_sub"] = env.db.scalar("SELECT EXISTS (SELECT id FROM article_subs WHERE path = ? AND user_id = ?)",
    article_path, env.user.not_nil!.id).as(Int64) != 0 if !env.user.nil?
  resp.to_json
end

get "/comments/recent" do |env|
  (get_comments(env.db, "true ORDER BY time_added DESC LIMIT ?", env.params.query["count"]?.try &.to_i || 10).map &.summary_dict).to_json
end

post "/comments/preview" do |env|
  Util.markdown(env.request.body.not_nil!.gets_to_end)
end

post "/comments" do |env|
  begin
    email = env.params.json["email"]?.try &.as(String) || ""
    cmt = Comment.new(
      name: env.params.json["name"].as(String).strip,
      body: env.params.json["body"].as(String),
      reply_to: env.params.json["reply_to"]?.try &.as(Int64),
      article_path: env.params.json["article_path"]?.try &.as(String) || "",
      article_title: "",
      ip: env.request.headers["x-forwarded-for"]?,
      ua: env.request.headers["user-agent"]?,
      time_added: Time.utc,
    )
  rescue err
    halt env, 400
  end
  cmt.validate env.db
  # Replies inherit their article path and title from their reply_to.
  if cmt.reply_to
    parent = get_comment(env.db, "id = ?", cmt.reply_to)
    cmt.article_path = parent.article_path
    cmt.article_title = parent.article_title
  else
    # For a top-level comment, we ned to fetch the article title.
    cmt.article_title = Util.get_article_title(cmt.article_path) || raise UserErr.new 400
  end
  # Make sure they aren't impersonating a registered user.
  # If it's not a logged in user, check for an email.
  if env.user.nil? && email != ""
    if !get_users(env.db, "email = ?", email).size
      # The email isn't claimed yet, so let them register it.
      env.user = register_email env.db, email.not_nil!
      if env.params.json["sub_site"]?
        env.user.not_nil!.sub_site = true
        add_user env.db, env.user.not_nil!
      end
    else
      raise UserErr.new 400, "That email belongs to a registered user. " +
                             "If it's you and you just claimed it, check your inbox for a registration link."
    end
  end
  cmt.user_id = env.user.try &.id
  add_comment env.db, cmt
  # Subscribe the user who posted it.
  set_sub_status(env.db, env.user.not_nil!.id, cmt.id, true) if env.user.try &.autosub
  spawn { send_reply_notifs env.db, cmt }
end

put "/comments" do |env|
  halt env, 401 if !env.user
  begin
    id = env.params.json["id"].as(Int64)
    name = env.params.json["name"].as(String)
    body = env.params.json["body"].as(String)
  rescue err
    halt env, status_code: 400, response: err || ""
  end
  cmt = get_comment(env.db, "id = ?", id)
  raise UserErr.new(403) if env.user.not_nil!.id != cmt.user_id && !env.user.not_nil!.admin
  cmt.name = name
  cmt.body = body
  cmt.time_changed = Time.utc
  cmt.validate env.db
  change_comment env.db, cmt
end

delete "/comments/:id" do |env|
  halt env, status_code: 401 if !env.user
  halt env, status_code: 403 if !env.user.not_nil!.admin
  env.db.exec("DELETE FROM comments WHERE id = ?", env.params.url["id"].to_i)
end

def send_reply_notifs(db, new_comment : Comment)
  listening = Set.new [] of String
  ignoring = Set.new [] of String
  # Never notify people about their own comment.
  ignoring.add db.scalar("SELECT email FROM users WHERE id = ?", new_comment.user_id).as(String) if new_comment.user_id
  # Travel up the tree, finding the lowest-level subscription or ignore for each user.
  comment = new_comment
  loop do
    get_comment_subs(db, comment.id).each do |email, sub|
        # If it's a sub and not overridden by a more specific ignore.
        listening.add(email) if sub && !ignoring.includes?(email)
        # if it's an ignore and not overridden by a more specific sub.
        ignoring.add(email) if !sub && !listening.includes?(email)
    end
    # If we're not at the top level, go on with the parent.
    if !comment.reply_to.nil?
      comment = get_comments(db, "id = ?", comment.reply_to)[0]
    else
      # If we're at the top level, do article subs.
      get_article_subs(db, comment.article_path).each do |email|
        listening.add(email) if !ignoring.includes?(email)
      end
      break
    end
  end
  # Email everbody.
  listening.each do |user|
    Emails.send(CFG.server_email, CFG.server_email_name, [user],
      "New reply on #{CFG.site_title}", Emails.reply_notif(new_comment))
  end
end
