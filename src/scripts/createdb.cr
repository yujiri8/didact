#!/usr/bin/env crystal

require "sqlite3"
require "../cfg"

# Will destroy the database if it already exists.
def createdb(dbname)
  DB.open "sqlite3:./#{dbname}" do |db|
    db.exec "CREATE TABLE users (
      id INTEGER PRIMARY KEY,
      email TEXT NOT NULL UNIQUE,
      auth TEXT NOT NULL,
      pw TEXT,
      name TEXT UNIQUE,
      admin BOOLEAN NOT NULL,
      autosub BOOLEAN NOT NULL,
      disable_reset BOOLEAN NOT NULL,
      sub_site BOOLEAN NOT NULL
    )"
    db.exec "CREATE TABLE comments (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      body TEXT NOT NULL,
      article_path TEXT NOT NULL,
      article_title TEXT NOT NULL,
      reply_to INTEGER REFERENCES comments(id) ON DELETE CASCADE,
      ip TEXT,
      ua TEXT,
      time_added TIMESTAMP NOT NULL,
      time_changed TIMESTAMP,
      user_id INTEGER REFERENCES users(id) ON DELETE SET NULL
    )"
    db.exec "CREATE TABLE subs (
      id INTEGER PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      comment_id INTEGER NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
      sub BOOLEAN NOT NULL
    )"
    db.exec "CREATE TABLE article_subs (
      id INTEGER PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      path TEXT NOT NULL,
      title TEXT NOT NULL
    )"
    db.exec "CREATE TABLE words (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      meaning TEXT NOT NULL,
      notes TEXT NOT NULL,
      time_added TIMESTAMP NOT NULL,
      time_changed TIMESTAMP NOT NULL
    )"
    db.exec "CREATE TABLE translations (
      word_id INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
      translation TEXT NOT NULL
    )"
    db.exec "CREATE TABLE tags (
      word_id INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
      tag TEXT NOT NULL
    )"
  end
end

createdb CFG.db
