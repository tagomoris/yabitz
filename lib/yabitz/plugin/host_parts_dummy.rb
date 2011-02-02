# -*- coding: utf-8 -*-

module Yabitz::Plugin
  module HostPartsDummy
    def self.plugin_type
      :hostlinkparts
    end
    def self.plugin_priority
      0
    end
    # This plugin module is for example, and NOT TESTED.
    # You can use jQuery in javascript_parts, and should write host_parts as haml template.

    # Shows link to top one of dnsname, as http://hostname.yourlocaldomain
    def self.javascript_parts
      <<EOJS
if (!('bind_events_detailbox_addons' in window)) {
    bind_events_detailbox_addons = [];
};
bind_events_detailbox_addons.push(function(){
    $('div.direct_http').each(function(){
        var linkblock = $(this);
        var linkurl = linkblock.attr('title');
        linkblock.replaceWith("<a href='http://" + linkurl + "'">[link]</a>");
    });
});
EOJS
    end

    def self.host_parts_displayed?(host, isadmin)
      host.dnsnames and host.dnsnames.first
    end

    def self.host_parts
      '%div.direct_http.inline{:title => h(@host.dnsnames.first.dnsname)} [link]'
    end
    # OR directory render link, without javascript_parts
    def self.host_parts
      <<EOT
%div.inline
  %a{:href => "http://" + @host.dnsnames.first.dnsname} [link]
EOT
    end
  end
end
