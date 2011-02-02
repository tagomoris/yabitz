# -*- coding: utf-8 -*-

# DO NOT require HERE !
# On loading plugin module, LOAD_PATH items from configuration plugin are not loaded yet.

module Yabitz::Plugin
  module DummyMiddlewareLoader
    def self.plugin_type
      :middleware_loader
    end
    def self.plugin_priority
      0
    end
    # This plugin module is for example, and NOT TESTED.

    def self.load_middleware(controller)
      require 'passenger-monitor'
      controller.use PassengerMonitor, :path => '/___server-status', :allow => ['10.0.0.0/8', '127.0.0.1']
    end
  end
end
