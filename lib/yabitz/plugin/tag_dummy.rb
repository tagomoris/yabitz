# -*- coding: utf-8 -*-

module Yabitz::Plugin
  module DummyCustomTag
    def self.plugin_type
      [:customtag, :handler]
    end
    def self.plugin_priority
      0
    end
    # This plugin module is for example, and NOT TESTED.

    def self.match?(tag)
      tag =~ /\Adummy:[^\s]+\Z/
    end

    def self.link(tag, host)
      "/path/to/dummy/tag" + tag
    end

    def self.addhandlers(controller)
      controller.get %r!/dummy/([-.0-9]+[0-9])?! do |tag|
        authorized?
        tag
      end
    end
  end
end
