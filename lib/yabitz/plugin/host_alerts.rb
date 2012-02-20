# -*- coding: utf-8 -*-

module Yabitz::Plugin
  module HostAlertsDefault
    def self.plugin_type
      :hostalerts
    end
    def self.plugin_priority
      0
    end

    #   alert_title #=> '注意対象' or string specified
    #   alert_face(bool_value)  #=> String
    def self.alert_title
      '注意対象'
    end

    def self.alert_face(bool_value)
      if bool_value
        '[警告あり]'
      else
        ''
      end
    end

    def self.default_value
      false
    end
  end
end
