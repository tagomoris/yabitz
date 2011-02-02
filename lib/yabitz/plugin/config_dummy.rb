# -*- coding: utf-8 -*-

# This configuration module is for dummy.
# Write your own configuration as your own plugin, with priority HIGHER THAN ZERO !

# env: :production, :development, :test

module Yabitz::Plugin
  module DummyConfig
    def self.plugin_type
      :config
    end
    def self.plugin_priority
      0
    end

    def self.extra_load_path
      []
    end

    DB_PARAMS = [:server, :user, :pass, :name, :port, :sock]
    LDAP_PARAMS = [:server, :port, :dn, :pass]

    CONFIG_SET = {
      :production => {
        :database => {
          :server => '10.0.0.1',
          :user => 'yabitz',
          :pass => 'ya-bi-tz',
          :name => 'yabitz',
          :port => nil,
          :sock => nil,
        },
        :ldap => {
          :server => '10.0.0.2',
          :port => 389,
          :dn => 'cn=ldapuser,cn=Users,dc=activedirectory,dc=livedoor,dc=intranet',
          :pass => 'ldap-ldap'
        },
      },
      :development => {
        :database => {
          :server => 'localhost',
          :user => 'root',
          :pass => nil,
          :name => 'yabitzdev',
          :port => nil,
          :sock => nil,
        },
        :ldap => {
          :server => '192.168.0.254',
          :port => 389,
          :dn => 'cn=ldapuser,cn=Users,dc=activedirectory,dc=livedoor,dc=intranet',
          :pass => 'ldap-ldap'
        },
      },
      :test => {
        :database => {
          :server => 'localhost',
          :user => 'root',
          :pass => nil,
          :name => 'yabitztest',
          :port => nil,
          :sock => nil,
        },
        :ldap => {
          :server => '192.168.0.254',
          :port => 389,
          :dn => 'cn=ldapuser,cn=Users,dc=activedirectory,dc=livedoor,dc=intranet',
          :pass => 'ldap-ldap'
        },
      },
    }

    def self.dbparams(env)
      DB_PARAMS.map{|sym| CONFIG_SET[env][:database][sym]}
    end

    def self.ldapparams(env)
      LDAP_PARAMS.map{|sym| CONFIG_SET[env][:ldap][sym]}
    end
  end
end
