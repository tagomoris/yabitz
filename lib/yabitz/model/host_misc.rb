# -*- coding: utf-8 -*-

require 'stratum'

require_relative '../plugin'
require_relative '../misc/validator'
require_relative '../misc/mapper'

module Yabitz
  module Model
    class TagChain < Stratum::Model
      table :tagchains
      field :host, :ref, :model => 'Yabitz::Model::Host'
      field :tagchain, :taglist, :empty => :ok

      def to_s
        self.tagchain.join(' ')
      end

      def self.build_tags_collection
        tags_date = {}
        Stratum.conn do |c|
          st = c.prepare("SELECT tagchain FROM tagchains WHERE tagchain IS NOT NULL AND head=? AND removed=?")
          st.execute(Stratum::Model::BOOL_TRUE, Stratum::Model::BOOL_FALSE)
          st.each do |result|
            tags = result.first.split(Stratum::Model::TAG_SEPARATOR)
            tags.each do |tag|
              datetime = Yabitz::OpeTagGenerator.match(tag)
              next unless datetime
              date = datetime[0,8]
              if tags_date[date]
                tags_date[date] += [tag] unless tags_date[date].include?(tag)
              else
                tags_date[date] = [tag]
              end
            end
          end
        end
        tags_date
      end

      def self.opetags_range(start_date, end_date)
        tags_date = self.build_tags_collection
        result = []
        tags_date.keys.sort.reverse.each do |t|
          if t.to_i >= start_date.to_i and t.to_i <= end_date.to_i
            result += [[t, tags_date[t]]]
          end
        end
        result
      end

      def self.active_opetags(num=20,order=:desc)
        tags_date = self.build_tags_collection
        result = []
        count = 0
        tags_date.keys.sort.reverse.each do |t|
          result += [[t, tags_date[t]]]
          count += tags_date[t].size
          break if count >= num
        end
        result
      end
    end

    class ContactMember < Stratum::Model
      include Yabitz::Mapper
      
      table :contactmembers
      field :name, :string, :length => 64
      field :telno, :string, :validator => 'check_telno', :empty => :ok
      field :mail, :string, :validator => 'check_mail', :empty => :ok
      field :comment, :string, :length => 4096, :empty => :ok
      field :badge, :string, :validator => 'check_badge', :empty => :ok
      field :position, :string, :length => 16, :empty => :ok

      def self.instanciate_mapping(fieldname)
        case fieldname
        when :name, :telno, :mail, :comment, :badge, :position
          {:method => :new, :class => String}
        else
          raise ArgumentError, "unknown field name '#{fieldname}'"
        end
      end

      def <=>(other)
        if self.badge.nil? or self.badge.empty? or other.badge.nil? or other.badge.empty?
          if (self.badge.nil? or self.badge.empty?) and (other.badge.nil? or other.badge.empty?)
            self.name <=> other.name
          else
            -1 * (self.badge.to_s <=> other.badge.to_s)
          end
        else
          self.badge.to_i <=> other.badge.to_i
        end
      end

      def to_s
        self.name
      end

      def check_telno(str)
        Yabitz::Validator.telnumber(str)
      end

      def check_mail(str)
        Yabitz::Validator.mailaddress(str)
      end

      def check_badge(str)
        str =~ /\A\d+\Z/ and str.length < 17
      end

      def self.has_member_source
        Yabitz::Plugin.get(:member).size > 0
      end

      def self.find_by_fullname_list(list)
        result = []
        Yabitz::Plugin.get(:member).each do |member_source|
          result += member_source.find_by_fullname_list(list)
        end
        result
      end

      def self.find_by_badge_list(list)
        result = []
        Yabitz::Plugin.get(:member).each do |member_source|
          result += member_source.find_by_badge_list(list)
        end
        result
      end

      def self.find_by_fullname_and_badge_list(pairs)
        result = []
        Yabitz::Plugin.get(:member).each do |member_source|
          result += member_source.find_by_fullname_and_badge_list(pairs)
        end
        result
      end
    end

    class Contact < Stratum::Model
      table :contacts
      field :label, :string, :length => 64
      field :services, :reflist, :model => 'Yabitz::Model::Service', :empty => :ok
      field :telno_daytime, :string, :validator => 'check_telno', :empty => :ok
      field :mail_daytime, :string, :validator => 'check_mail', :empty => :ok
      field :telno_offtime, :string, :validator => 'check_telno', :empty => :ok
      field :mail_offtime, :string, :validator => 'check_mail', :empty => :ok
      field :members, :reflist, :model => 'Yabitz::Model::ContactMember', :empty => :ok
      field :memo, :string, :length => 4096, :empty => :ok
      
      def <=>(other)
        self.label <=> other.label
      end

      def to_s
        self.label
      end

      def check_telno(str)
        Yabitz::Validator.telnumber(str)
      end

      def check_mail(str)
        Yabitz::Validator.mailaddress(str)
      end
    end
  end
end
