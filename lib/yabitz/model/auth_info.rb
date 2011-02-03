# -*- coding: utf-8 -*-

require 'stratum'

require_relative '../misc/init'
require_relative '../misc/logging'
require_relative '../plugin'

module Yabitz
  module Model
    class AuthInfo < Stratum::Model
      PRIV_ROOT = 'ROOT'
      PRIV_ADMIN = 'ADMIN'
      PRIV_LIST = [PRIV_ROOT, PRIV_ADMIN].freeze

      table :auth_info
      field :valid, :bool, :default => true
      field :name, :string, :length => 64
      field :fullname, :string, :length => 64
      field :priv, :string, :selector => PRIV_LIST, :empty => :allowed

      def to_s
        self.name
      end

      def <=>(other)
        self.name <=> other.name
      end

      def self.authenticate(username, password, sourceip='')
        fullname = nil
        Yabitz::Plugin.get(:auth).each do |handler|
          fullname = handler.authenticate(username, password, sourceip)
          break if fullname
        end
                       
        user = self.query(:name => username, :unique => true)
        if fullname and user.nil?
          pre_operator = begin
                           Stratum.current_operator()
                         rescue RuntimeError
                           # ignore
                           nil
                         end
          Stratum.current_operator(self.get_root)
          user = self.new
          user.name = username
          user.fullname = fullname
          user.priv = nil # TODO auto admin-nize to NSG user?
          user.save
          Stratum.current_operator(pre_operator) if pre_operator
        end

        result = if user and fullname
                   "success"
                 elsif not fullname
                   "failed"
                 else
                   "forbidden"
                 end
        Yabitz::Logging::log_auth(username, result, (user ? user.oid : ""), sourceip)

        return nil unless fullname and user.valid?

        Stratum.current_operator(user)
        user
      end

      def self.get_root
        self.query(:priv => PRIV_ROOT, :unique => true)
      end

      def self.has_administrator?
        self.query(:priv => PRIV_ADMIN).select{|x| x.name != 'batchmaker'}.size > 0
      end

      def set_admin
        self.priv = PRIV_ADMIN
      end

      def admin?
        self.priv == PRIV_ADMIN
      end

      def root?
        self.priv == PRIV_ROOT
      end
    end
  end
end
