#!/usr/bin/env crystal

require "db"
require "sqlite3"
require "../cfg"
require "../emails"
require "../models"
require "../db"

footer = "To edit your notification settings, visit https://#{CFG.hostname}/account"

db = DB.open "sqlite3://#{CFG.db}"

subs = get_users(db, "sub_site")
if subs.size == 0
  puts "You have no site subscribers. Don't waste your breath."
  exit 0
end

printf "Subject: "
subject = gets
puts "Type the message body to email to subscribers."
puts "The footer \"#{footer}\" will be added automatically."

body = STDIN.gets_to_end + "\n\n" + footer

subs.each do |sub|
  Emails.send(CFG.server_email, CFG.server_email_name, [sub.email], subject, body, wait: true)
end
