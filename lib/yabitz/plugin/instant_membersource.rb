# -*- coding: utf-8 -*-

require 'digest/sha1'
require 'mysql'

module Yabitz::Plugin
  module InstantMemberHandler
    def self.plugin_type
      [:auth, :member]
    end
    def self.plugin_priority
      100
    end

    DB_HOSTNAME = "localhost"
    DB_USERNAME = "root"
    DB_PASSWORD = nil
    DATABASE_NAME = "yabitz_member_source"
    TABLE_NAME = "list"
    def self.query(sql, *args)
      result = []
      conn = Mysql.connect(DB_HOSTNAME, DB_USERNAME, DB_PASSWORD, DATABASE_NAME)
      conn.charset = 'utf8'
      st = conn.prepare(sql)
      st.execute(*args)
      st.each{|r| result.push(r.map{|v| v.respond_to?(:encode) ? v.encode('utf-8') : v})}
      st.free_result
      result
    end

    def self.authenticate(username, password, sourceip=nil)
      results = self.query("SELECT fullname,name FROM #{TABLE_NAME} WHERE name=? AND passhash=?", username, Digest::SHA1.hexdigest(password))
      if results.size != 1
        return nil
      end
      results.first.first
    end

    MEMBERLIST_FIELDS = [:fullname, :badge, :position]

    def self.find_by_fullname_list(fullnames)
      cond = (['fullname=?'] * fullnames.size).join(' OR ')
      results = self.query("SELECT #{MEMBERLIST_FIELDS.map(&:to_s).join(',')} FROM #{TABLE_NAME} WHERE #{cond}", *fullnames)

      fullnames.map{|fn| results.select{|ary| ary.first == fn}.first}
    end

    def self.find_by_badge_list(badges)
      cond = (['badge=?'] * badges.size).join(' OR ')
      results = self.query("SELECT #{MEMBERLIST_FIELDS.map(&:to_s).join(',')} FROM #{TABLE_NAME} WHERE #{cond}", *badges)

      badges.map{|bd| results.select{|ary| ary[1] == bd}.first}
    end

    def self.find_by_fullname_and_badge_list(pairs)
      cond = (['(fullname=? AND badge=?)'] * pairs.size).join(' OR ')
      results = self.query("SELECT #{MEMBERLIST_FIELDS.map(&:to_s).join(',')} FROM #{TABLE_NAME} WHERE #{cond}", *(pairs.flatten))

      pairs.map{|fn,bd| results.select{|ary| ary[0] == fn and ary[1] == bd}.first}
    end

    def self.convert(values)
      Hash[*([MEMBERLIST_FIELDS, values].transpose)]
    end
  end
end
