#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'mysql'

module Yabitz
  module MemberSourceSchema
    DATABASE_NAME = "yabitz_member_source"
    TABLE_NAME = "list"
    
    def self.main(hostname, username, password)
      conn = Mysql.connect(hostname, username, password, nil)
      drop_database(conn)
      create_database(conn)
      conn.close()

      conn = Mysql.connect(hostname, username, password, DATABASE_NAME)
      create_tables(conn)
      conn.close()
    end

    def self.create_database(conn)
      conn.query("CREATE DATABASE #{DATABASE_NAME} DEFAULT CHARACTER SET 'utf8'")
    end

    def self.drop_database(conn)
      conn.query("DROP DATABASE IF EXISTS #{DATABASE_NAME}")
    end

    def self.create_tables(conn)
      sqls = []
      sqls.push <<-EOSQL
CREATE TABLE #{TABLE_NAME} (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
name        VARCHAR(64)     NOT NULL UNIQUE KEY,
passhash    VARCHAR(40)     NOT NULL,
fullname    VARCHAR(64)     NOT NULL,
mailaddress VARCHAR(256)    ,
badge       VARCHAR(16)     ,
position    VARCHAR(16)
) ENGINE=InnoDB charset='utf8'
EOSQL

      sqls.each do |s|
        conn.query(s)
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  hostname = ARGV[0]
  username = ARGV[1]
  password = ARGV[2]
  Yabitz::MemberSourceSchema.main(hostname, username, password)
end

