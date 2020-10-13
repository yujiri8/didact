require "kemal"
require "./cfg"
require "./models"
require "./util"
require "./comments"
require "./users"
require "./emails"

class HTTP::Server::Context
  property user : User?
end

# An error that should be shown to the user.
class UserErr < Exception
  property code, msg

  def initialize(@code : Int = 500, @msg : String = "")
    super(msg)
  end
end

# Middleware to check what user is sending the request and set default content type.
before_all do |env|
  auth = env.request.cookies["auth"]?
  env.user = User.where{ _auth == auth.value }.first if !auth.nil?
  env.response.content_type = "application/json"
end

# Don't send the default error page.
error 404 do
end

# All errors we want to specially handle are caught here, even ones that send codes other than 500.
error 500 do |env, exc|
  case exc
  when Jennifer::RecordNotFound
    env.response.status_code = 404
  when UserErr
    env.response.status_code = exc.code
    env.response.print exc.msg
    env.response.close
  else
    Emails.send CFG.server_email, CFG.server_email_name, [CFG.admin_email], "Error at #{CFG.hostname}",
      Emails.err_notif(env, exc)
  end
  nil
end

serve_static false
Kemal.config.powered_by_header = false
Kemal.run
