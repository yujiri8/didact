#!/bin/sh
# Assumes a new Digital Ocean droplet running FreeBSD.
set -e
ssh root@$1 freebsd-update cron install
ssh root@$1 reboot || true
echo "Waiting 90 seconds for server to come back up"
sleep 90
ssh root@$1 pkg install -y git crystal openssl shards nginx npm sqlite3 opensmtpd entr
ssh root@$1 service nginx enable
ssh root@$1 service smtpd enable
ssh root@$1 service smtpd start
ssh root@$1 git clone https://github.com/yujiri8/didact
ssh root@$1 cp -r didact/example/ didact/content
ssh root@$1 'cd didact; shards --production'
ssh root@$1 'cd didact; npm install'
ssh root@$1 'cd didact; ./build.sh'
ssh root@$1 cp didact/didact.yml.example didact/didact.yml
ssh root@$1 'cd didact; src/scripts/install.cr'
ssh root@$1 mkdir -p /etc/letsencrypt/live/mysite.com
scp fullchain.pem privkey.pem root@$1:/etc/letsencrypt/live/mysite.com
ssh root@$1 service nginx start
ssh root@$1 'cd didact; ./src/scripts/createdb.cr'
ssh root@$1 'cd didact; ./didact-template'
ssh root@$1 'cd didact; ./didact-server' &
echo "Server running. Try:"
echo "* post comment without name - should give error"
echo "* preview comment with markdown body"
echo "* post comment 1 and 2 without email, 3 and 4 as replies to 1 and 5 and 6 as replies to 2"
echo "* post comment 7 with email"
echo "* log into that account"
echo "* switch sub to ignore, back to sub, and then clear it"
echo "* go to /. re-sub to a comment, ignore, clear"
echo "* sub to / and post comment 8. should not get notif"
echo "* sub to /cat, then go to notifs and delete it"
echo "* try setting name and password"
echo "* sub to 1 and 6, ignore 2 and 3"
echo "* log out and post a top-level comment on /. should get notif"
echo "* reply to comments 3, 4, 5, and 6. should get notifs for the replies to 4 and 6"
echo "* ensure the claimed name can't be taken"
echo "* sign up without posting"
echo "* test sub_site, autosub, and disable_reset"
echo "* use src/scripts/email-subscribers.cr"
echo "* edit a comment"
echo "* delete a comment with replies and subscriptions"
