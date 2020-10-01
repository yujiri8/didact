#!/usr/bin/env crystal

require "../cfg"
require "ecr"

File.open("/etc/nginx/nginx.conf", "w") do |file|
  ECR.embed("cfg/nginx/nginx.conf", file)
end
File.open("/etc/nginx/sites/didact", "w") do |file|
  ECR.embed("cfg/nginx/sites/didact", file)
end
