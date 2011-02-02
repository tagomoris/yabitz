# -*- coding: utf-8 -*-

require_relative '../plugin'

module Yabitz
  module Config
    class Base
      def initialize(env, config_plugin_module)
        @env = case env
               when :production, :prod
                 :production
               when :development, :dev
                 :development
               when :test
                 :test
               else
                 raise ArgumentError, "invalid environment: '#{env}'"
               end
        @config = config_plugin_module
      end

      def name
        @env
      end

      def credit_html()
        if @config.respond_to?(:credit_html)
          @config.credit_html(@env)
        else
          "Yabitz / 2011 tagomoris at gmail.com / Apache License v2.0"
        end
      end

      def extra_load_path()
        return [] unless @config.respond_to?(:extra_load_path)
        @config.extra_load_path(@env)
      end

      def dbparams()
        @config.dbparams(@env)
      end

      def ldapparams()
        return [] unless @config.respond_to?(:ldapparams)
        @config.ldapparams(@env)
      end

      def method_missing(name, *args)
        @config.send(name, @env, *args)
      end
    end
  end

  def self.set_global_environment(env)
    prior_config = Yabitz::Plugin.get(:config).first
    $yabitz_config = Yabitz::Config::Base.new(env, prior_config)
  end
  
  def self.config()
    raise RuntimeError, "not set environment yet" unless $yabitz_config
    $yabitz_config
  end
end
