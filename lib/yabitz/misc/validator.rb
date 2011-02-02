# -*- coding: utf-8 -*-

require 'ipaddr'

module Yabitz
  module Validator
    def self.mailaddress(str)
      # だってめんどくさい上にメール通知とか予定にないし(とか
      str.length < 257 and str.split('@').size > 1 and str.split('@')[0].length > 0 and hostname(str.split('@')[-1])
    end

    def self.hostname(str)
      str =~ /\A[a-zA-Z0-9.-]{1,255}\Z/ and
        str[0] != '.' and str[-1] != '.' and
        str.split('.').inject(true){|v,i| v and i.length > 0 and i.length < 64 and i[0] != '-' and i[-1] != '-'}
    end

    def self.ipaddress(str)
      begin
        ip = IPAddr.new(str)
      rescue ArgumentError
        return nil
      end
      return "v6" if ip.ipv6?
      "v4"
    end

    def self.telnumber(str)
      str.length < 65 # it's life.
    end
  end
end
