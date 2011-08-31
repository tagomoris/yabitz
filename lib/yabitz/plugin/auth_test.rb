# -*- coding: utf-8 -*-

module Yabitz::Plugin
  module TestAuthenticate
    def self.plugin_type
      :auth
    end
    def self.plugin_priority
      1
    end


    # MUST returns full_name (as String)
    # if authentication failed, return nil
    def self.authenticate(username, password, sourceip=nil)
      if Yabitz.config().name == :development and username =~ /\Atest/
        return username
      end
      nil
    end
  end
end
