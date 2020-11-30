#!/usr/bin/env crystal

require "db"
require "sqlite3"
require "../cfg"

# Will destroy the database if it already exists.
def createdb(dbname)
  DB.open "sqlite3:./#{dbname}" do |db|
    db.exec "CREATE TABLE users (
      id BIGSERIAL PRIMARY KEY,
      email text NOT NULL UNIQUE,
      auth text NOT NULL,
      pw text,
      name text UNIQUE,
      admin boolean NOT NULL,
      autosub boolean NOT NULL,
      disable_reset boolean NOT NULL,
      sub_site boolean NOT NULL
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

createdb CFG.db
