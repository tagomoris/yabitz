# -*- coding: utf-8 -*-

module Yabitz::Plugin
  module BatchAuthenticate
    def self.plugin_type
      :auth
    end
    def self.plugin_priority
      1
    end

    # MUST returns full_name (as String)
    # if authentication failed, return nil
    def self.authenticate(username, password, sourceip=nil)
      if username == 'batchmaker' and password == 'batchmaker'
        return username
      end
      nil
    end
  end
end
