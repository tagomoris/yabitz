# -*- coding: utf-8 -*-

module Yabitz
  module Plugin
    # All plugin modules MUST have class methods below.
    #   plugin_type #=> symbol of plugin type, or list of symbol
    #   plugin_priority #=> Integer number, bigger priority plugin used more. priorities less than 0 are ignored plugin (dummy/demo).
    #
    # [+] is optional class methods
    #
    # :config
    #   dbparams(env)
    #   [+] credit_html(env)
    #   [+] extra_load_path(env)
    #   [+] ldapparams(env)
    #
    # :middleware_loader
    #   [+] load_middleware(controller)
    #
    # :auth
    #   authenticate(username, password, sourceip) #=> fullname(String), or nil
    #
    # :handler
    #   addhandler(controller)
    #   [+] css #=> css as String
    #   [+] js #=> javascript as String
    #
    # :handler_hook - obsolete.
    #   [+] host_insert(host)
    #   [+] host_update(pre_update_host, post_update_host)
    #   [+] host_delete(host)
    #   [+] contact_update(contact)
    #   [+] contactmember_update(members)
    #   
    # :error_handler - obsolete.
    #   adderrorhandler(controller)
    #
    # :hostlinkparts
    #   host_parts_displayed?(host, isadmin) #=> true/false
    #   host_parts #=> haml template as String
    #   [+] javascript_parts #=> javascript as String
    #
    # :member
    #   find_by_fullname_list(list)
    #   find_by_badge_list(list)
    #   find_by_fullname_and_badge(list)
    #
    # :racktype
    #   name #=> String
    #   datacenter #=> String
    #   rack_label_pattern #=> regex
    #   rackunit_label_pattern #=> regex
    #   rack_label(rackunit_label) #=> String
    #   dividing(rackunit_label) #=> String
    #   rack_label_example #=> String ('Xn-Xnn')
    #   rackunit_label_example #=> String ('Xn-Xnn-Xn / Xn-Xnn-Xn[fr]')
    #   upper_rackunit_labels(from, num) #=> Array of String
    #   rackunit_space_list(rack_label) #=> Array of list of String of rack's content, from top to bottom, [[full, front, rear], ...]
    #   rackunit_status_list(rack_label) #=> [units_fully_available_for_host, units_partially_or_fully_used_for_host]
    #   rack_display_template #=> String
    #   
    # :customtag
    #   match?(tag)
    #   link(tag, host)
    #
    @@plugins = {}

    def self.load_plugin_view(plugin_file_path, template_directory, view_name)
      open(File.dirname(plugin_file_path) + '/' + template_directory + '/' + view_name) {|fio| fio.read}
    end

    def self.plugin_patterns
      [
       File.expand_path(File.dirname(__FILE__)) + '/plugin/*.rb',
      ]
    end

    def self.load_plugins
      self.plugin_patterns.each do |pattern|
        Dir.glob(pattern).each do |file|
          load file
        end
      end
    end

    def self.load_all
      self.load_plugins
      self.constants.map{|c| self.const_get(c)}.select{|m| m.is_a?(Module)}.each do |m|
        next unless m.respond_to?(:plugin_type) and m.respond_to?(:plugin_priority)
        [m.plugin_type].flatten.each do |type|
          @@plugins[type] ||= []
          @@plugins[type].push(m)
        end
      end
    end

    def self.get(plugin_type)
      (@@plugins[plugin_type] || []).select{|p| p.plugin_priority.to_i > 0}.sort{|a,b| b.plugin_priority.to_i <=> a.plugin_priority.to_i}
    end
  end
end

Yabitz::Plugin.load_all
