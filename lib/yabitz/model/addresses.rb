# -*- coding: utf-8 -*-

require_relative '../misc/init'

require 'stratum'
require_relative '../misc/validator'
require_relative '../misc/racktype'

require 'ipaddr'

module Yabitz
  module Model
    class ServiceURL < Stratum::Model
      table :serviceurls
      field :url, :string, :validator => 'check_url', :normalizer => 'normalize_url'
      fieldex :url, "httpもしくはhttpsではじまる、正常なドメイン名のURLを入力してください"
      field :services, :reflist, :model => 'Yabitz::Model::Service', :empty => :ok, :serialize => :oid

      def <=>(other)
        self.url <=> other.url
      end

      def to_s
        self.url
      end

      def check_url(url)
        url =~ /\Ahttps?:\/\/[a-z0-9][-a-z0-9]*\.[a-z0-9][-.a-z0-9]*(:[0-9]+)?.*/ and url.size < 1024
      end

      def self.normalize_url(url)
        parts = url.split('/')
        unless parts[0].downcase == 'http:' or parts[0].downcase == 'https:'
          parts.unshift('') unless parts[0] == ''
          parts.unshift('http:')
        end
        parts[0].downcase!
        parts[2].downcase!
        parts.join('/')
      end
    end

    class DNSName < Stratum::Model
      table :dnsnames
      field :dnsname, :string, :validator => 'check_hostname'
      fieldex :dnsname, "DNS名は少なくともひとつのドットを含み、アンダースコアは使えません"
      field :hosts, :reflist, :model => 'Yabitz::Model::Host', :empty => :ok, :serialize => :oid

      def <=>(other)
        selfparts = self.dnsname.split('.').reverse
        if selfparts[0] == 'xen'
          selfparts.push(selfparts.shift)
        end
        otherparts = other.dnsname.split('.').reverse
        if otherparts[0] == 'xen'
          otherparts.push(otherparts.shift)
        end

        (0...selfparts.size).each do |i|
          return 1 if otherparts[i].nil?
          val = selfparts[i] <=> otherparts[i]
          return val if val != 0
        end
        if selfparts.size < otherparts.size
          return -1
        end
        0
      end

      def to_s
        self.dnsname
      end

      def check_hostname(str)
        Yabitz::Validator.hostname(str)
      end
    end
    
    class DummyIPAddress
      attr_reader :address, :version
      def oid ; nil; end
      def id ; nil; end
      def hosts ; []; end
      def hosts_by_id ; []; end
      def holder ; false ; end
      def holder? ; false ; end
      def notes ; "" ; end
      def <=>(other)
        if self.version != other.version
          return self.version <=> other.version
        end
        IPAddr.new(self.address) <=> IPAddr.new(other.address)
      end
      def to_s ; self.address ; end
      def to_addr ; IPAddr.new(self.address) ; end

      def set(str)
        result = Yabitz::Validator.ipaddress(str)
        case result
        when "v4"
          @address = str
          @version = ::Yabitz::Model::IPAddress::IPv4
        when "v6"
          @address = str
          @version = ::Yabitz::Model::IPAddress::IPv6
        else
          raise Stratum::FieldValidationError.new("invalid ipaddress #{str}", ::Yabitz::Model::IPAddress.class, :address)
        end
      end

      def initialize(addr)
        self.set(addr)
      end

      def quoted_address ; self.address.tr('.', '_') ; end
    end

    class IPAddress < Stratum::Model
      IPv4 = 'IPv4'
      IPv6 = 'IPv6'
      IP_VERSIONS = [IPv4, IPv6].freeze
      
      table :ipaddresses
      field :address, :string, :validator => 'check_ipaddress'
      field :version, :string, :selector => IP_VERSIONS, :default => IPv4
      field :hosts, :reflist, :model => 'Yabitz::Model::Host', :empty => :ok, :serialize => :oid
      field :holder, :bool, :default => false
      field :notes, :string, :length => 1024, :empty => :ok

      def <=>(other)
        if self.version != other.version
          return self.version <=> other.version
        end
        IPAddr.new(self.address) <=> IPAddr.new(other.address)
      end

      def to_s
        self.address
      end

      def to_addr
        IPAddr.new(self.address)
      end

      def quoted_address
        self.address.tr('.', '_')
      end

      def self.dequote(str)
        str.tr('_', '.')
      end

      def set(str)
        result = Yabitz::Validator.ipaddress(str)
        case result
        when "v4"
          self.address = str
          self.version = IPv4
        when "v6"
          self.address = str
          self.version = IPv6
        else
          raise Stratum::FieldValidationError.new("invalid ipaddress #{str}", self.class, :address)
        end
      end

      def check_ipaddress(str)
        Yabitz::Validator.ipaddress(str)
      end
    end
    
    class IPSegment < Stratum::Model
      AREA_LOCAL = 'local'
      AREA_GLOBAL = 'global'
      IP_SEGMENT_AREAS = [AREA_LOCAL, AREA_GLOBAL].freeze

      table :ipsegments
      field :address, :string, :validator => 'check_ipaddress'
      field :netmask, :string, :validator => 'check_netmask'
      field :version, :string, :selector => IPAddress::IP_VERSIONS, :default => IPAddress::IPv4
      field :area, :string, :selector => IP_SEGMENT_AREAS, :default => AREA_LOCAL
      field :ongoing, :bool, :default => true
      field :notes, :string, :length => 1024, :empty => :ok

      def <=>(other)
        if self.version != other.version
          return self.version <=> other.version
        end
        IPAddr.new(self.address) <=> IPAddr.new(other.address)
      end

      def to_s
        self.address + '/' + self.netmask
      end

      def to_addr
        IPAddr.new(self.address + '/' + self.netmask)
      end

      def set(addr, mask)
        result = Yabitz::Validator.ipaddress(addr)
        case result
        when "v4"
          self.address = addr
          self.netmask = mask
          self.version = IPAddress::IPv4
          if self.netmask.to_i > 32
            raise Stratum::FieldValidationError.new("invalid ipaddress #{addr}/#{mask}", self.class, :address)
          end
        when "v6"
          self.address = addr
          self.netmask = mask
          self.version = IPAddress::IPv6
        else
          raise Stratum::FieldValidationError.new("invalid ipaddress #{addr}/#{mask}", self.class, :address)
        end
      end

      def check_ipaddress(str)
        Yabitz::Validator.ipaddress(str)
      end

      def check_netmask(str)
        str =~ /\A\d{1,3}\Z/ and (str.to_i.to_s == str) and str.to_i >= 0 and str.to_i <= 128 # for IPv6
      end
    end
    
    class RackUnit < Stratum::Model
      table :rackunits
      field :rackunit, :string, :validator => 'check_rackunit'
      fieldex :rackunit, "次のような形式が定義されています: " + Yabitz::RackTypes.list.map(&:rackunit_label_example).join(", ")
      field :dividing, :string, :selector => Yabitz::RackTypes::DIVIDINGS, :default => Yabitz::RackTypes::DIVIDING_FULL
      field :rack, :ref, :model => 'Yabitz::Model::Rack'
      field :hosts, :reflist, :model => 'Yabitz::Model::Host', :empty => :ok, :serialize => :oid
      field :holder, :bool, :default => false
      field :notes, :string, :length => 1024, :empty => :ok

      def self.query_or_create(*args)
        obj = super

        unless obj.rack
          if Stratum.current_operator
            if obj.saved?
              obj.rack_set and obj.save
            else
              obj.rack_set
            end
          end
        end
        obj
      end

      def <=>(other)
        self.rackunit <=> other.rackunit
      end

      def to_s
        self.rackunit
      end

      def rack_set
        racktype = Yabitz::RackTypes.search_by_unit(self.rackunit)
        rack = Yabitz::Model::Rack.query_or_create(:label => racktype.rack_label(self.rackunit), :type => racktype.name, :datacenter => racktype.datacenter)
        unless rack.type and rack.datacenter
          rack.type = racktype.name
          rack.datacenter = racktype.datacenter
          rack.save
        end
        self.rack = rack
      end

      def check_rackunit(str)
        Yabitz::RackTypes.search_by_unit(str)
      end
    end
    
    class Rack < Stratum::Model
      table :racks
      field :label, :string, :validator => 'check_racklabel'
      fieldex :label, "次のような形式が定義されています: " + Yabitz::RackTypes.list.map(&:rack_label_example).join(", ")
      field :type, :string, :selector => Yabitz::RackTypes.list.map(&:name), :default => Yabitz::RackTypes.default.name
      field :datacenter, :string, :selector => Yabitz::RackTypes.list.map(&:datacenter), :default => Yabitz::RackTypes.default.datacenter
      field :ongoing, :bool, :default => true
      field :notes, :string, :length => 1024, :empty => :ok

      def <=>(other)
        if (self.datacenter <=> other.datacenter) != 0
          self.datacenter <=> other.datacenter
        elsif (self.type <=> other.type) != 0
          self.type <=> other.type
        else
          self.label <=> other.label
        end
      end

      def to_s
        self.label
      end

      def check_racklabel(str)
        Yabitz::RackTypes.search(str)
      end
    end
  end
end
