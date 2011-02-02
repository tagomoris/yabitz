# -*- coding: utf-8 -*-

require 'sinatra/base'
require 'stratum'
require_relative './model'
require_relative './misc/opetag_generator'

require 'cgi'

module Sinatra
  module AuthenticateHelper
    def unauthorized!
      response['WWW-Authenticate'] = %(Basic realm="Yabitz Authentication")
      session[:username] = ""
      throw(:halt, [401, "Not Authorized\n"])
    end

    def forcecheck_basic_auth
      auth = Rack::Auth::Basic::Request.new(request.env)
      return nil unless auth.provided? and auth.basic? and auth.credentials

      Yabitz::Model::AuthInfo.authenticate(*(auth.credentials), request.ip)
    end

    def check_session
      return nil unless session[:username] and session[:username] != ""
      user = Yabitz::Model::AuthInfo.query(:name => session[:username], :unique => true)
      return nil unless user and user.valid?
      user
    end

    def authorized?
      admin_exists = Yabitz::Model::AuthInfo.has_administrator?
      @user = (check_session or forcecheck_basic_auth)
      @isadmin = false
      if @user
        session[:username] = @user.name
        @isadmin = (@user.admin? or not admin_exists)
      end
      Stratum.current_operator(@user) if @user
      @user
    end

    def protected!
      unless authorized?
        unauthorized!
      end
    end

    def admin_protected!
      unless authorized?
        unauthorized!
      end
      unless @isadmin
        throw(:halt, [403, "Forbidden\n"])
      end
    end
  end
  helpers AuthenticateHelper

  module EscapeHelper
    def h(string)
      CGI.escapeHTML(string.to_s)
    end

    def u(string)
      CGI.escape(string.to_s)
    end

    def roundoff(num, d=0)
      x = 10**d
      if num < 0
        (num * x - 0.5).ceil.quo(x).to_f
      else
        (num * x + 0.5).floor.quo(x).to_f
      end
    end
  end
  helpers EscapeHelper

  module HostCategorize
    def categorize_host(hosts)
      result = {}
      Yabitz::Model::Host::STATUS_LIST.each do |s|
        result[s] = {:list => [], :hw => {'不明' => 0}, :os => {'不明' => 0}}
      end
      result['total'] = {:hw => {'不明' => 0}, :os => {'不明' => 0}}
      hosts.each do |host|
        result[host.status][:list].push(host)
        if host.hwinfo
          result[host.status][:hw][host.hwinfo.name] ||= 0
          result[host.status][:hw][host.hwinfo.name] += 1
          result['total'][:hw][host.hwinfo.name] ||= 0
          result['total'][:hw][host.hwinfo.name] += 1
        else
          result[host.status][:hw]['不明'] += 1
          result['total'][:hw]['不明'] += 1
        end
        if host.os and not host.os.empty?
          result[host.status][:os][host.os] ||= 0
          result[host.status][:os][host.os] += 1
          result['total'][:os][host.os] ||= 0
          result['total'][:os][host.os] += 1
        else
          result[host.status][:os]['不明'] += 1
        end
      end
      result
    end
  end
  helpers HostCategorize

  module PartialHelper
    def partial(template, *args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      options.merge!(:layout => false)
      if collection = options.delete(:collection) then
        collection.inject([]) do |buffer, member|
          buffer << haml(template, options.merge(:locals => {template => member}))
        end.join("\n")
      else
        haml(template, options)
      end
    end

    EDITABLE_FIELD_TEMPLATE = 'common/editable_field'.to_sym
    PARTIAL_OPTION = {:layout => false}

    def field_editable(model, obj, type, field, title, value, blank_spacer, options={})
      # options:
      # :display_value => value
      # :everybody => bool
      # :link => url
      # :opt_class => ClassName, :opt_value => :fieldname, :opt_label => :fieldname
      # :values => [value of option list], :labels => [label of option list]
      cmn = {:action => "/ybz/#{model}/#{obj.oid}", :target_id => obj.id}
      opts = cmn.merge({:input_type => type, :fieldname => field, :fieldtitle => title, :fieldvalue => value, :blanklabel => blank_spacer})
      if type == :combobox or type == :selector
        opts.update({ :listproc => Proc.new{options[:opt_class].all.sort},
                      :list_item_value_field => options[:opt_value],
                      :list_item_label_field => options[:opt_label]})
      end
      if type == :simpleselector
        opts.update({ :listproc => Proc.new{[options[:values],options[:labels]].transpose},
                      :list_item_value_field => :first,
                      :list_item_label_field => :last})
      end

      if options[:everybody]
        opts.update({:everybody => true})
      end
      if options[:link]
        opts.update({:link => options[:link]})
      end
      if options[:display_value]
        opts.update({:display_value => options[:display_value]})
      end
      haml EDITABLE_FIELD_TEMPLATE, PARTIAL_OPTION, opts
    end
  end
  helpers PartialHelper

  module LinkGenerator
    def anchored_tag(tag, host)
      customtag_plugin = Yabitz::Plugin.get(:customtag).select{|p| p.match?(tag)}.first
      link_path = if customtag_plugin
                    customtag_plugin.link(tag, host)
                  elsif Yabitz::OpeTagGenerator.match(tag)
                    "/ybz/host/operation/" + tag
                  else
                    "/ybz/smartsearch?keywords=" + CGI.escape(tag)
                  end
      haml('%a{:href => link_path}&= tagstring', {:layout => false, :locals => {:link_path => link_path, :tagstring => tag}})
    end
  end
  helpers LinkGenerator

  module ValueComparator
    def equal_in_fact(origin, requested)
      if origin.nil? or origin == '' or origin == []
        requested.nil? or requested == '' or requested == []
      elsif origin.is_a?(String)
        requested and origin == requested
      elsif origin.is_a?(Integer)
        requested and origin == requested.to_i
      elsif origin.is_a?(Array)
        requested.is_a?(Array) and
          origin.size == requested.size and
          [origin, requested].transpose.inject(true){|r,pair| r and equal_in_fact(pair.first, pair.last)}
      elsif origin.is_a?(Stratum::Model)
        requested and origin.to_s == requested
      else
        raise ArgumentError, "unexpected arguments #{origin} and #{requested}"
      end
    end
  end
  helpers ValueComparator
end
