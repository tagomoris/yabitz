# -*- coding: utf-8 -*-

require_relative '../misc/ldap_handler'

module Yabitz::Plugin
  module DummyLDAPAuthenticate
    def self.plugin_type
      :auth
    end
    def self.plugin_priority
      0
    end
    # This plugin module is for example, and NOT TESTED.

    AD_SEARCH_PATHS = ["ou=Users,dc=ad,dc=intranet"]

    # MUST returns full_name (as String)
    # if authentication failed, return nil
    def self.authenticate(username, password, sourceip=nil)
      # Read LDAP, Database, CSV, or use PAM, ...
      # You should write your own code about your environment, as plugin.

      unless self.username_checker(username)
        return nil
      end

      result = Yabitz::LDAPHandler.search(AD_SEARCH_PATHS, "(SAMACCOUNTNAME=#{username})")
      return nil unless result.size == 1
      
      ent = result.first
      return nil unless Yabitz::LDAPHandler.try_auth(ent['dn'].first, password)
      ent['DISPLAYNAME'].first.force_encoding('utf-8')
    end

    def self.username_checker(name)
      name =~ /\A[-.a-zA-Z0-9_]+\Z/
    end
  end
end
