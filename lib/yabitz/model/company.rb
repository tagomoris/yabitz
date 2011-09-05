# -*- coding: utf-8 -*-

require 'stratum'

require_relative '../misc/validator'
require_relative '../misc/mapper'

module Yabitz
  module Model
    class Content < Stratum::Model
      include Yabitz::Mapper

      CHARGING_NORMAL = 'NORMAL'
      CHARGING_NO_COUNT = 'NO_COUNT'
      CHARGING_SHARED = 'SHARED'
      CHARGING_LABELS = [CHARGING_NORMAL,CHARGING_NO_COUNT, CHARGING_SHARED].freeze

      table :contents
      field :name, :string, :length => 64
      field :charging, :string, :selector => CHARGING_LABELS, :empty => :ok
      field :code, :string, :length => 16, :empty => :ok
      field :dept, :ref, :model => 'Yabitz::Model::Dept', :serialize => :oid
      field :services, :reflist, :model => 'Yabitz::Model::Service', :empty => :ok, :serialize => :oid

      def self.instanciate_mapping(fieldname)
        case fieldname
        when :name, :charging, :code
          {:method => :new, :class => String}
        when :dept
          {:method => :get, :class => Yabitz::Model::Dept}
        when :services
          {:method => :query_or_create, :class => Yabitz::Model::Service, :field => :name}
        else
          raise ArgumentError, "unknown field name '#{fieldname}'"
        end
      end

      def <=>(other)
        selfcode_empty = (self.code.nil? or self.code.empty? or (self.code.to_i.to_s != self.code))
        othercode_empty = (other.code.nil? or other.code.empty? or (other.code.to_i.to_s != other.code))
        if selfcode_empty ^ othercode_empty
          if othercode_empty
            -1
          else
            1
          end
        elsif selfcode_empty and othercode_empty
          self.name.downcase <=> other.name.downcase
        elsif self.code and other.code
          self.code.to_i <=> other.code.to_i
        elsif self.code or other.code
          -1 * (self.code.to_i <=> other.code.to_i)
        else
          self.oid <=> other.oid
        end
      end

      def to_s
        c = (self.code.nil? or self.code.empty?) ? 'NONE' : self.code
        self.name + ' (' + c + ')'
      end

      def has_code?
        not (self.code.nil? or self.code == '' or self.code == 'NONE')
      end

      def charging_title
        self.class.charging_title(self.charging)
      end

      def self.charging_title(c)
        case c
        when CHARGING_NO_COUNT
          "課金対象外"
        when CHARGING_SHARED
          "全体共通"
        when CHARGING_NORMAL
          "通常"
        else
          "通常"
        end
      end
    end

    class Service < Stratum::Model
      include Yabitz::Mapper

      table :services
      field :name, :string, :length => 64
      field :content, :ref, :model => 'Yabitz::Model::Content', :serialize => :oid
      field :mladdress, :string, :validator => 'check_mailaddress', :empty => :ok
      field :urls, :reflist, :model => 'Yabitz::Model::ServiceURL', :empty => :ok
      field :contact, :ref, :model => 'Yabitz::Model::Contact', :empty => :ok
      field :notes, :string, :length => 4096, :empty => :ok

      def self.instanciate_mapping(fieldname)
        case fieldname
        when :name, :mladdress, :notes
          {:method => :new, :class => String}
        when :content
          {:method => :get, :class => Yabitz::Model::Content}
        when :contact
          {:method => :query_or_create, :class => Yabitz::Model::Contact, :field => :label}
        when :urls
          {:method => :query_or_create, :class => Yabitz::Model::ServiceURL, :field => :url}
        else
          raise ArgumentError, "unknown field name '#{fieldname}'"
        end
      end

      def <=>(other)
        self.name.downcase <=> other.name.downcase
      end

      def to_s
        self.name
      end

      def check_mailaddress(str)
        Yabitz::Validator.mailaddress(str)
      end
    end

    class Dept < Stratum::Model
      include Yabitz::Mapper

      table :depts
      field :name, :string, :length => 64

      def self.instanciate_mapping(fieldname)
        case fieldname
        when :name
          {:method => :new, :class => String}
        else
          raise ArgumentError, "unknown field name '#{fieldname}'"
        end
      end

      def <=>(other)
        self.name.downcase <=> other.name.downcase
      end

      def to_s
        self.name
      end
    end
  end
end
