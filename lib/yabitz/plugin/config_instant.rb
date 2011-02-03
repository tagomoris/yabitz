# -*- coding: utf-8 -*-

module Yabitz::Plugin
  module InstantConfig
    def self.plugin_type
      :config
    end
    def self.plugin_priority
      1
    end

    def self.extra_load_path(env)
      if env == :production
        ['~/Documents/stratum']
      else
        ['~/Documents/stratum']
      end
    end

    DB_PARAMS = [:server, :user, :pass, :name, :port, :sock]

    CONFIG_SET = {
      :database => {
        :server => 'localhost',
        :user => 'root',
        :pass => nil,
        :name => 'yabitz_instant',
        :port => nil,
        :sock => nil,
      },
      :test_database => {
        :server => 'localhost',
        :user => 'root',
        :pass => nil,
        :name => 'yabitztest',
        :port => nil,
        :sock => nil,
      },
    }

    def self.dbparams(env)
      if env == :test
        DB_PARAMS.map{|sym| CONFIG_SET[:test_database][sym]}
      else
        DB_PARAMS.map{|sym| CONFIG_SET[:database][sym]}
      end
    end
  end
end
