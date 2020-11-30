require "crypto/bcrypt/password"

post "/users/login" do |env|
  begin
    email = env.params.json["email"].as(String)
    pw = env.params.json["pw"].as(String)
  rescue err
    halt env, 400
  end
  user = get_user(env.db, "email = ?", email)
  if user.nil? || user.pw.nil? || !Crypto::Bcrypt::Password.new(user.not_nil!.pw.not_nil!).verify(pw)
    halt env, 401
  end
  grant_auth(env, user.not_nil!)
end

def gen_auth_token
  Random.new.hex 32
end

# Shortcut.
def set_cookie(env, name, val, max_age = CFG.cookie_lifetime)
  env.response.cookies << HTTP::Cookie.new(name, val, secure: true,
    samesite: HTTP::Cookie::SameSite::Lax, expires: Time.utc + max_age.seconds)
end

# Sets login cookies.
def grant_auth(env : HTTP::Server::Context, user : User)
  set_cookie(env, "auth", user.auth)
  set_cookie(env, "name", user.name || "", max_age: user.name ? CFG.cookie_lifetime : 0)
  set_cookie(env, "email", user.email || "", max_age: user.email ? CFG.cookie_lifetime : 0)
  set_cookie(env, "admin", "1", max_age: user.admin ? CFG.cookie_lifetime : 0)
end

# A wrapper around register_email that turns it into a valid endpoint handler.
post "/users/claim" do |env|
  halt env, 400 if env.params.json["email"]?.nil?
  register_email(env.db, env.params.json["email"].as(String))
end

# Validate an email, create the uesr, and send a confirm email. Returns the created user if successful.
def register_email(db, email : String)
  raise UserErr.new(400, "That doesn't look like a valid email address") if !/[^@]+@[\w]+\.[\w]+/.match(email)
  user = get_users(db, "email = ?", email)[0]?
  if user
    # They're asking to claim a registered email. Inform them if the user has disabled password reset.
    raise UserErr.new(403, "That email belongs to a registered user, who has disabled password reset.") \
       if user.disable_reset
    # just send the confirmation.
    send_confirm_email(user)
    return user
  end
  # The email doesn't already exist. They're making a new account.
  user = User.new(email: email, auth: gen_auth_token())
  add_user db, user
  send_confirm_email(user)
  user
end

def send_confirm_email(user)
  msg = Emails.confirm(email: user.email, token: user.auth)
  Emails.send(CFG.server_email, CFG.server_email_name, [user.email],
    "Subscribing you to reply notifications on #{CFG.site_title}", msg)
end

get "/users/prove" do |env|
  user = get_users(env.db, "auth = ?", env.params.query["token"])[0]?
  next env.redirect("/invalid_token") if user.nil?
  # Might as well change the token.
  user.auth = gen_auth_token
  change_user env.db, user
  env.redirect("/account")
  grant_auth(env, user)
end

get "/users/notifs" do |env|
  halt env, 401 if !env.user
  {
    "comment_subs":  get_user_comment_subs(env.db, env.user.not_nil!.id),
    "article_subs":  get_user_article_subs(env.db, env.user.not_nil!.id),
    "autosub":       env.user.not_nil!.autosub,
    "disable_reset": env.user.not_nil!.disable_reset,
    "site":          env.user.not_nil!.sub_site,
  }.to_json
end

put "/users/notifs" do |env|
  halt env, 401 if !env.user
  begin
    id = env.params.json["id"]?.as(Int64 | Nil)
    path = env.params.json["path"]?.as(String | Nil)
    state = env.params.json["state"].as(Bool | Nil)
    raise "" if path.nil? && id.nil?
  rescue
    raise UserErr.new 400
  end
  # Comment subscription.
  if id
    # Make sure the comment exists.
    env.db.scalar("SELECT id FROM comments WHERE id = ?", id)
    set_sub_status(env.db, env.user.not_nil!.id, id, state)
    # Article subscription.
  elsif path
    set_article_sub(env.db, env.user.not_nil!.id, path, state.as(Bool))
  end
end

put "/users/pw" do |env|
  halt env, 401 if !env.user
  begin
    pw = env.request.body.not_nil!.gets_to_end
  rescue
    raise UserErr.new 400
  end
  env.user.not_nil!.pw = Crypto::Bcrypt::Password.create(pw).to_s
  # Change the auth token after changing password.
  env.user.not_nil!.auth = gen_auth_token
  change_user env.db, env.user.not_nil!
  grant_auth(env, env.user.not_nil!)
end

put "/users/subsite" do |env|
  halt env, 401 if !env.user
  begin
    sub_site = JSON.parse(env.request.body.not_nil!).as_bool
  rescue
    raise UserErr.new 400
  end
  env.user.not_nil!.sub_site = sub_site
  change_user env.db, env.user.not_nil!
end

put "/users/autosub" do |env|
  halt env, 401 if !env.user
  begin
    autosub = JSON.parse(env.request.body.not_nil!).as_bool
  rescue
    raise UserErr.new 400
  end
  env.user.not_nil!.autosub = autosub
  change_user env.db, env.user.not_nil!
end

put "/users/disablereset" do |env|
  halt env, 401 if !env.user
  begin
    disable_reset = JSON.parse(env.request.body.not_nil!).as_bool
  rescue
    raise UserErr.new 400
  end
  env.user.not_nil!.disable_reset = disable_reset
  change_user env.db, env.user.not_nil!
end
