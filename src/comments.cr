get "/comments" do |env|
  if id = env.params.query["id"]?.try &.to_i?
    cmts = [Comment.find!(id)]
  elsif article_path = env.params.query["article_path"]?
    cmts = Comment.where(article_path: article_path, reply_to: nil).select
  else
    raise UserErr.new 400
  end
  resp = {
    "comments":    cmts.map &.dict(user: env.user, raw: env.params.query["raw"]?),
    "article_sub": env.user ? !env.user.not_nil!.article_subs.find_by(path: article_path).nil? : nil,
  }
  next resp.to_json
end

get "/comments/recent" do |env|
  next (Comment.limit(env.params.query["count"]?.try &.to_i || 10).map &.summary_dict).to_json
end

post "/comments/preview" do |env|
  next Util.markdown(env.request.body.not_nil!.gets_to_end)
end

post "/comments" do |env|
  begin
    email = env.params.json["email"]?.try &.as(String) || ""
    sub_site = env.params.json["sub_site"]?.try &.as(Bool) || false
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
  cmt.validate
  # Replies inherit their article path and title from their reply_to.
  if cmt.reply_to
    parent = Comment.find!(cmt.reply_to)
    cmt.article_path = parent.article_path
    cmt.article_title = parent.article_title
  else
    # For a top-level comment, we ned to fetch the article title.
    cmt.article_title = Util.get_article_title(cmt.article_path) || raise UserErr.new 400
  end
  # Make sure they aren't impersonating a registered user.
  # If it's not a logged in user, check for an email.
  if env.user.nil? && email != ""
    if User.find_by(email: email).nil?
      # The email isn't claimed yet, so let them register it.
      env.user = register_email email.not_nil!
      if env.params.json["sub_site"]?
        env.user.not_nil!.sub_site = true
        env.user.not_nil!.save!
      end
    else
      raise UserErr.new 400, "That email belongs to a registered user. " +
                             "If it's you and you just claimed it, check your inbox for a registration link."
    end
  end
  cmt.user_id = env.user.try &.id
  cmt.save!
  # Subscribe the user who posted it.
  Subscription.create! user_id: env.user.not_nil!.id, comment_id: cmt.id if env.user.try &.autosub
  spawn { send_reply_notifs cmt }
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
  cmt = Comment.find!(id)
  raise UserErr.new(403) if env.user != cmt.user && !env.user.not_nil!.admin
  cmt.name = name
  cmt.body = body
  cmt.time_changed = Time.utc
  cmt.validate
  cmt.save!
end

delete "/comments/:id" do |env|
  halt env, status_code: 401 if !env.user
  halt env, status_code: 403 if !env.user.not_nil!.admin
  # TODO get a real delete feature.
  Comment.find!(env.params.url["id"].to_i).destroy!
end

def send_reply_notifs(new_comment : Comment)
  listening = Set.new [] of String
  ignoring = Set.new [] of String
  # Never notify people about their own comment.
  ignoring.add new_comment.user.email if new_comment.user_id
  # Travel up the tree, finding the lowest-level subscription or ignore for each user.
  comment = new_comment
  while true
    comment.subs.each do |sub|
      # If it's a sub and not overridden by a more specific ignore.
      listening.add(sub.user.email) if sub.sub && !ignoring.includes?(sub.user.email)
      # if it's an ignore and not overridden by a more specific sub.
      ignoring.add(sub.user.email) if !sub.sub && !listening.includes?(sub.user.email)
    end
    # If we're not at the top level, go on with the parent.
    if comment.reply_to
      comment = comment.parent
    else
      # If we're at the top level, do article subs.
      ArticleSubscription.where(path: comment.article_path).each do |sub|
        listening.add(sub.user.email) if !ignoring.includes?(sub.user.email)
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
