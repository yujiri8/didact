require "../cfg"
require "../emails"
require "../models"

footer = "To edit your notification settings, visit https://#{CFG.hostname}/account."

subs = User.where(sub_site: true).select
if subs.size == 0
  puts "You have no site subscribers. Don't waste your breath."
  exit 0
end

printf "Subject: "
subject = gets
puts "Type the message body to email to subscribers."
puts "The footer \"#{footer}\" will be added automatically."

subs.each do |sub|
  Emails.send(CFG.server_email, CFG.server_email_name, [sub.email],
    subject, STDIN.gets_to_end + "\n\n" + footer, wait: true)
end
