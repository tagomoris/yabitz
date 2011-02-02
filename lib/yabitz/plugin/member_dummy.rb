# -*- coding: utf-8 -*-

require 'csv'

module Yabitz::Plugin
  module DummyMemberSource
    def self.plugin_type
      :member
    end
    def self.plugin_priority
      0
    end
    # This plugin module is for example, and NOT TESTED.
    # for example, csv data source.

    MEMBERLIST_CSV_FILE_PATH = '/home/yabitz/members.csv'
    MEMBERLIST_CSV_FIELD_LIST = [:username, :fullname, :mailaddress, :badge, :position]

    def self.find_by_fullname_list(fullnames)
      fullnames.map{|fn| self.find_from_csv{|ent| ent[:fullname] == fn}}
    end

    def self.find_by_badge_list(badges)
      badges.map{|bd| self.find_from_csv{|ent| ent[:badge] == bd}}
    end

    def self.find_by_fullname_and_badge_list(pairs)
      pairs.map{|pair| self.find_from_csv{|ent| ent[:fullname] == pair.first and ent[:badge] == pair.last}}
    end

    # very cheap implement... you should rewrite here.
    def self.find_from_csv(&blk)
      CSV.foreach(MEMBERLIST_CSV_FILE_PATH, encoding: "UTF-8:UTF-8", headers: :first_row) do |row|
        next if row.header_row?
        return self.convert(row) if yield self.convert(row)
      end
      nil
    end

    def self.convert(row)
      Hash[*([MEMBERLIST_CSV_FIELD_LIST, row.fields].transpose)]
    end
  end
end
