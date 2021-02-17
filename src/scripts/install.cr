#!/usr/bin/env crystal

require "../cfg"
require "ecr"

# On Linux, Nginx config is under /etc. On FreeBSD, user-installed stuff is prefixed with /usr/local.
prefix = File.exists?("/usr/local/etc/nginx") ? "/usr/local" : ""

File.open("#{prefix}/etc/nginx/nginx.conf", "w") do |file|
  ECR.embed("cfg/nginx/nginx.conf", file)
end
# Not all distributions have this dir.
Dir.mkdir_p("#{prefix}/etc/nginx/sites")
File.open("#{prefix}/etc/nginx/sites/didact", "w") do |file|
  ECR.embed("cfg/nginx/sites/didact", file)
end
