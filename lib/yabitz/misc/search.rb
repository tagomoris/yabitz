# -*- coding: utf-8 -*-

require_relative '../model'
require_relative './racktype'

module Yabitz
  module DetailSearch
    def self.search_part(field, pattern_string)
      pattern = Regexp.compile(pattern_string)
      case field
      when 'service'
        pattern = Regexp.compile(pattern_string, Regexp::IGNORECASE)
        Yabitz::Model::Service.regex_match(:name => pattern, :oidonly => true).map do |srv_oid|
          Yabitz::Model::Host.query(:service => srv_oid, :oidonly => true)
        end.flatten
      when 'rackunit'
        Yabitz::Model::RackUnit.regex_match(:rackunit => pattern).map(&:hosts_by_id).flatten.uniq
      when 'hwid'
        Yabitz::Model::Host.regex_match(:hwid => pattern, :oidonly => true)
      when 'dnsname'
        Yabitz::Model::DNSName.regex_match(:dnsname => pattern).map(&:hosts_by_id).flatten.uniq
      when 'ipaddress'
        Yabitz::Model::IPAddress.regex_match(:address => pattern).map(&:hosts_by_id).flatten.uniq
      when 'hwinfo'
        Yabitz::Model::HwInformation.regex_match(:name => pattern, :oidonly => true).map do |info_oid|
          Yabitz::Model::Host.query(:hwinfo => info_oid, :oidonly => true)
        end.flatten
      when 'os'
        Yabitz::Model::Host.regex_match(:os => pattern, :oidonly => true)
      when 'tag'
        Yabitz::Model::TagChain.query(:tagchain => pattern).map(&:host_by_id).uniq
      end
    end

    def self.search(andor, conditions)
      oidset = []
      conditions.each do |field, pattern|
        each_set = self.search_part(field, pattern)
        if oidset.size == 0
          oidset.push(*each_set)
        else
          if andor == 'AND'
            oidset = oidset & each_set
          elsif andor == 'OR'
            oidset = oidset | each_set
          else
            raise ArgumentError, "invalid and/or specification: #{andor}"
          end
        end
      end
      Yabitz::Model::Host.get(oidset)
    end
  end

  module SmartSearch
    def self.kind(string)
      [
       [:service, "サービス", :service],
       [:serviceurl, "サービスURLをもつサービス", :service],
       [:dnsname, "DNS名", :host],
       [:hwid, "HWID", :host],
       [:ipaddress, "IPアドレス", :host],
       [:rackunit, "ラック位置", :host],
       [:tag, "タグ", :host],
       [:brickhwid, "機器情報 HWID", :brick],
       [:brickserial, "機器情報 シリアル", :brick]
      ]
    end

    def self.search(kind, keyword)
      case kind
      when :ipaddress
        Yabitz::Model::IPAddress.regex_match(:address => Regexp.compile(keyword)).map(&:hosts).flatten.compact
      when :service
        pattern = Regexp.compile(keyword, Regexp::IGNORECASE)
        Yabitz::Model::Service.regex_match(:name => pattern).flatten.compact
      when :serviceurl
        Yabitz::Model::ServiceURL.query(:url => keyword).map(&:services).flatten.compact
      when :rackunit
        Yabitz::Model::RackUnit.regex_match(:rackunit => Regexp.compile(keyword)).map(&:hosts).flatten.compact
      when :dnsname
        Yabitz::Model::DNSName.regex_match(:dnsname => Regexp.compile(keyword)).map(&:hosts).flatten.compact
      when :hwid
        Yabitz::Model::Host.query(:hwid => keyword)
      when :tag
        Yabitz::Model::TagChain.query(:tagchain => keyword).map(&:host).compact
      when :brickhwid
        Yabitz::Model::Brick.query(:hwid => keyword)
      when :brickserial
        Yabitz::Model::Brick.query(:serial => keyword)
      end
    end
  end
end
