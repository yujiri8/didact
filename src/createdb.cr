require "db"
require "pg"

# Will destroy the database if it already exists. The database will be owned by Postgres user "didact".
def createdb(dbname)
  DB.open "postgres://postgres@localhost/postgres" do |db|
    # Create the didact user if it doesn't exist.
    unless db.scalar "SELECT EXISTS (SELECT rolname FROM pg_roles WHERE rolname = 'didact')"
      db.exec "CREATE ROLE didact WITH LOGIN"
    end
    db.exec "DROP DATABASE IF EXISTS #{dbname}"
    db.exec "CREATE DATABASE #{dbname} WITH OWNER didact"
  end
  # Now connect to the created database and fill it out.
  DB.open "postgres://didact@localhost/#{dbname}" do |db|
    db.exec "CREATE TABLE users (
      id BIGSERIAL PRIMARY KEY,
      email text NOT NULL,
      auth text NOT NULL,
      pw text,
      pgp text,
      name text,
      admin boolean,
      autosub boolean,
      sub_site boolean
    )"
    db.exec "CREATE TABLE comments (
      id BIGSERIAL PRIMARY KEY,
      name text NOT NULL,
      body text NOT NULL,
      article_path text NOT NULL,
      article_title text NOT NULL,
      reply_to bigint REFERENCES comments(id) ON DELETE CASCADE,
      ip text,
      ua text,
      time_added timestamp NOT NULL,
      time_changed timestamp,
      user_id bigint REFERENCES users(id) ON DELETE SET NULL
    )"
    db.exec "CREATE TABLE subs (
      id BIGSERIAL PRIMARY KEY,
      user_id bigint NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      comment_id bigint NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
      sub boolean NOT NULL
    )"
    db.exec "CREATE TABLE article_subs (
      id BIGSERIAL PRIMARY KEY,
      user_id bigint NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      path text NOT NULL,
      title text NOT NULL
    )"
  end
end

if ARGV.size == 0
  STDERR << "Specify a database name."
  Process.exit 1
end

createdb ARGV[0]
