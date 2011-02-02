#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'digest/sha1'
require 'mysql'

DATABASE_NAME = "yabitz_member_source"
TABLE_NAME = "list"

# id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
# name        VARCHAR(64)     NOT NULL UNIQUE KEY,
# passhash    VARCHAR(40)     NOT NULL,
# fullname    VARCHAR(64)     NOT NULL,
# mailaddress VARCHAR(256)    ,
# badge       VARCHAR(16)     ,
# position    VARCHAR(16)     ,

def show_pronpt(pronpt, shadow_input=false)
  print pronpt
  system "stty -echo" if shadow_input
  input = $stdin.gets.chomp
  if shadow_input
    system "stty echo"
    puts ""
  end
  input
end

def error_exit(msg)
  puts msg
  exit
end

db_hostname = ARGV[0]
db_username = ARGV[1]
db_password = nil
if ARGV[2] == '-p'
  db_password = show_pronpt("DB password: ", true)
end

def check_username_exists(conn, username)
  st = conn.prepare("SELECT count(*) FROM #{TABLE_NAME} WHERE name=?")
  st.execute(username)
  result = st.fetch.first.to_i
  st.free_result
  return result > 0
end

def insert_user_record(conn, username)
  puts "ユーザデータを新規作成します"

  pass1st = show_pronpt("パスワードを入力してください: ", true)
  pass2nd = show_pronpt("パスワードをもう一度入力してください: ", true)
  error_exit "入力されたパスワードが一致しません" unless pass1st == pass2nd

  fullname = show_pronpt("氏名: ")
  error_exit "氏名は64文字までしか登録できません" if fullname.length > 64
  fullname = username if fullname.empty?

  mailaddress = show_pronpt("メールアドレス(省略可): ")
  badge = show_pronpt("社員番号(省略可): ")
  position = show_pronpt("役職(省略可): ")
  
  st = conn.prepare("INSERT INTO #{TABLE_NAME} SET name=?,passhash=?,fullname=?,mailaddress=?,badge=?,position=?")
  st.execute(username, Digest::SHA1.hexdigest(pass1st), fullname, mailaddress, badge, position)
end

def change_user_record(conn, username)
  puts "既存のユーザデータを更新します"

  password = show_pronpt("現在のパスワードを入力してください: ", true)

  st = conn.prepare("SELECT count(*) FROM #{TABLE_NAME} WHERE name=? AND passhash=?")
  st.execute(username, Digest::SHA1.hexdigest(password))
  result = st.fetch.first.to_i
  st.free_result

  error_exit "パスワードが間違っています" if result != 1
  
  st = conn.prepare("SELECT fullname,mailaddress,badge,position FROM #{TABLE_NAME} WHERE name=? AND passhash=?")
  st.execute(username, Digest::SHA1.hexdigest(password))
  x_fullname, x_mailaddress, x_badge, x_position = st.fetch
  st.free_result

  pass1st = show_pronpt("パスワードを変更する場合は入力してください: ", true)
  if pass1st.length > 0
    pass2nd = show_pronpt("パスワードをもう一度入力してください: ", true)
    error_exit "入力されたパスワードが一致しません" unless pass1st == pass2nd
  else
    pass1st = password
  end

  fullname = show_pronpt("氏名 [#{x_fullname}]: ")
  error_exit "氏名は64文字までしか登録できません" if fullname.length > 64
  fullname = x_fullname if fullname.empty?

  mailaddress = show_pronpt("メールアドレス [#{x_mailaddress}]: ")
  mailaddress = x_mailaddress if mailaddress.empty?
  badge = show_pronpt("社員番号 [#{x_badge}]: ")
  badge = x_badge if badge.empty?
  position = show_pronpt("役職 [#{x_position}]: ")
  position = x_position if position.empty?

  st = conn.prepare("UPDATE #{TABLE_NAME} SET passhash=?,fullname=?,mailaddress=?,badge=?,position=? WHERE name=?")
  st.execute(Digest::SHA1.hexdigest(pass1st), fullname, mailaddress, badge, position, username)
end

conn = Mysql.connect(db_hostname, db_username, db_password, DATABASE_NAME)
conn.charset = 'utf8'

username = show_pronpt("ユーザ名を入力してください: ")
if check_username_exists(conn, username)
  change_user_record(conn, username)
else
  insert_user_record(conn, username)
end
