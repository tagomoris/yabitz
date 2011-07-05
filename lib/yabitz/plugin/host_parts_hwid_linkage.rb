# -*- coding: utf-8 -*-

module Yabitz::Plugin
  module HostPartsHwidLinkage
    def self.plugin_type
      :hostlinkparts
    end
    def self.plugin_priority
      1
    end

    def self.host_parts_displayed?(host, isadmin)
      host.hwid and not host.hwid.empty? and Yabitz::Model::Brick.query(:hwid => host.hwid, :count => true) > 0
    end

    def self.host_parts
      <<EOT
%div.inline
  %a{:href => '/ybz/brick/hwid/' + h(@host.hwid)} [機器]
EOT
    end
  end
end
