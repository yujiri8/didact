#!/usr/bin/env crystal

require "../cfg"
require "ecr"

prefix = File.exists?("/usr/local/etc/nginx") ? "/usr/local" : ""

File.open("#{prefix}/etc/nginx/nginx.conf", "w") do |file|
  ECR.embed("cfg/nginx/nginx.conf", file)
end
File.open("#{prefix}/etc/nginx/sites/didact", "w") do |file|
  ECR.embed("cfg/nginx/sites/didact", file)
end
