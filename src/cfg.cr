require "yaml"

class Cfg
  include YAML::Serializable
  property hostname : String
  property site_title : String
  property server_email : String
  property server_email_name : String
  property admin_email : String
  property icon : String?
  property twitter : String?
  property preview_image : String?
  property cookie_lifetime : Int64
  property db : String
end

CFG = begin
  Cfg.from_yaml(File.open "didact.yml")
rescue err
  STDERR.puts "Your didact.yml is invalid: #{err}"
  exit 1
end
