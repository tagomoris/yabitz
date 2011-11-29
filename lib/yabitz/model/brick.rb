# -*- coding: utf-8 -*-

require 'stratum'

require_relative '../misc/validator'
require_relative '../misc/mapper'
require_relative './host'
require_relative './company'

module Yabitz
  module Model
    class Brick < Stratum::Model
      include Yabitz::Mapper

      STATUS_STOCK = 'STOCK'
      STATUS_IN_USE = 'IN_USE'
      STATUS_SPARE = 'SPARE'
      STATUS_REPAIR = 'REPAIR'
      STATUS_BROKEN = 'BROKEN'
      STATUS_LIST = [STATUS_STOCK, STATUS_IN_USE, STATUS_SPARE, STATUS_REPAIR, STATUS_BROKEN]

      STATUS_ORDER_MAP = {STATUS_STOCK => 0, STATUS_REPAIR => 1, STATUS_SPARE => 2, STATUS_BROKEN => 3, STATUS_IN_USE => 4}

      table :bricks
      field :hwid, :string, :length => 16
      field :productname, :string, :length => 64
      field :delivered, :string, :validator => 'check_delivered', :normalizer => 'normalize_delivered'
      fieldex :delivered, "例: 2011-07-05"
      field :status, :string, :selector => STATUS_LIST, :default => STATUS_STOCK
      field :served, :string, :validator => 'check_served', :normalizer => 'normalize_delivered', :empty => :ok
      fieldex :served, "例: 2011-08-23"
      field :serial, :string, :length => 1024, :empty => :ok
      field :heap, :string, :length => 128, :empty => :ok
      field :notes, :string, :length => 4096, :empty => :ok

      CSVFIELDS = [:oid, :hwid, :productname, :delivered, :status, :served, :serial, :heap]

      def self.instanciate_mapping(fieldname)
        case fieldname
        when :hwid, :productname, :delivered, :status, :served, :serial, :heap, :notes
          {:method => :new, :class => String}
        else
          raise ArgumentError, "unknown field name #{fieldname}"
        end
      end

      def to_s
        "#{self.productname} (#{self.hwid})"
      end

      def <=>(other)
        # status(stock->repair->broken->in_use?) -> hwid
        return STATUS_ORDER_MAP[self.status] <=> STATUS_ORDER_MAP[other.status] unless self.status == other.status
        self.hwid <=> other.hwid
      end

      def served!
        if not self.served or self.served.length < 1
          self.served = Time.now.strftime('%Y-%m-%d')
        end
      end

      def self.normalize_delivered(str)
        return nil if str.nil?
        tred = str.tr('−ａ-ｚＡ-Ｚ０-９／　．', '-a-zA-Z0-9/ .')
        if tred =~ /\A(\d{4})[-.\/ ]?(\d{1,2})[-.\/ ]?(\d{1,2})\Z/
          return sprintf('%04d', $1.to_i) + '-' + sprintf('%02d', $2.to_i) + '-' + sprintf('%02d', $3.to_i)
        end
        tred
      end

      def check_served(str)
        if not str or str.length < 1
          true
        else
          check_delivered(str)
        end
      end

      def check_delivered(str)
        if str =~ /\A(\d{4})-(\d{2})-(\d{2})\Z/
          begin
            year = $1.to_i
            mon = $2.to_i
            day = $3.to_i
            t = Time.local(year, mon, day)
            if (t.year == year and t.mon == mon and t.day == day)
              return true
            end
            return false
          rescue ArgumentError
            return false
          end
        else
          false
        end
      end

      def self.served_between(from, to)
        # {service => [brick, brick, ...], ...}
        result_by_id = {}
        bricks = self.choose(:served, :lowlevel => true){|s| s and s >= from and s <= to}
        bricks.each do |brick|
          relateds = Yabitz::Model::Host.query(:hwid => brick.hwid, :before => to + ' 23:59:59').select{|h| h.parent_by_id.nil?}
          target_service_oid = nil
          target_service_oid = relateds.first.service_by_id if relateds.size > 0
          result_by_id[target_service_oid] ||= []
          result_by_id[target_service_oid].push(brick)
        end
        service_unknowns = result_by_id.delete(nil)
        result = {}
        Yabitz::Model::Service.get(result_by_id.keys).each do |service|
          result[service] = result_by_id[service.oid]
        end
        if service_unknowns
          result[nil] = service_unknowns
        end
        result
      end

      def self.status_title(s)
        case s
        when STATUS_STOCK
          "在庫"
        when STATUS_IN_USE
          "使用中"
        when STATUS_SPARE
          "障害交換用"
        when STATUS_REPAIR
          "修理中"
        when STATUS_BROKEN
          "故障"
        else
          raise ArgumentError, "unknown status: #{s}"
        end
      end

      def self.build_raw_csv(fields, bricks)
        require 'csv'
        ret_lines = [fields.map{|f| f.to_s.upcase}.to_csv]
        bricks.each do |h|
          ret_lines.push(fields.map{|f| [h.send(f)].flatten.map(&:to_s).join(' ')}.to_csv)
        end
        ret_lines.join
      end
    end
  end
end
