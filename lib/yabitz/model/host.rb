# -*- coding: utf-8 -*-

require 'stratum'

require_relative '../misc/validator'
require_relative '../misc/mapper'
require_relative '../misc/hosttype'

module Yabitz
  module Model
    class Host < Stratum::Model
      include Yabitz::Mapper

      STATUS_IN_SERVICE = 'IN_SERVICE'
      STATUS_UNDER_DEV = 'UNDER_DEV'
      STATUS_NO_COUNT = 'NO_COUNT'
      STATUS_STANDBY = 'STANDBY'
      STATUS_SUSPENDED = 'SUSPENDED'
      STATUS_REMOVING = 'REMOVING'
      STATUS_REMOVED = 'REMOVED'
      STATUS_MISSING = 'MISSING'
      STATUS_OTHER = 'OTHER'
      STATUS_LIST = [STATUS_IN_SERVICE, STATUS_UNDER_DEV, STATUS_NO_COUNT, STATUS_STANDBY,
                     STATUS_SUSPENDED, STATUS_REMOVING, STATUS_REMOVED, STATUS_MISSING, STATUS_OTHER].freeze

      table :hosts
      field :service, :ref, :model => 'Yabitz::Model::Service', :serialize => :oid
      field :status, :string, :selector => STATUS_LIST
      field :type, :string, :selector => Yabitz::HostType.names
      field :parent, :ref, :model => 'Yabitz::Model::Host', :empty => :ok, :manualmaint => true, :serialize => :full
      field :children, :reflist, :model => 'Yabitz::Model::Host', :empty => :ok, :serialize => :meta
      field :rackunit, :ref, :model => 'Yabitz::Model::RackUnit', :empty => :ok
      field :hwid, :string, :length => 16, :empty => :ok
      field :hwinfo, :ref, :model => 'Yabitz::Model::HwInformation', :empty => :ok
      field :cpu, :string, :validator => 'check_cpu', :normalizer => 'normalize_cpu', :empty => :ok
      fieldex :cpu, "CPU数[SPACE]モデル名等 / 例: '4 Intel Xeon L5630 @ 2.13GHz'"
      field :memory, :string, :validator => 'check_memory', :normalizer => 'normalize_memory', :empty => :ok
      fieldex :memory, "例: 8g, 32GB , 5GiB , 1.5TB"
      field :disk, :string, :validator => 'check_disk', :normalizer => 'normalize_disk', :empty => :ok
      fieldex :disk, "例: 500GB, HDD 2TB, SSD 400GB*2, SAS 137GBx8 RAID-5"
      field :os, :string, :length => 64, :empty => :ok
      field :dnsnames, :reflist, :model => 'Yabitz::Model::DNSName', :empty => :ok
      field :localips, :reflist, :model => 'Yabitz::Model::IPAddress', :column => 'local_ipaddrs', :empty => :ok
      field :globalips, :reflist, :model => 'Yabitz::Model::IPAddress', :column => 'global_ipaddrs', :empty => :ok
      field :virtualips, :reflist, :model => 'Yabitz::Model::IPAddress', :column => 'virtual_ipaddrs', :empty => :ok
      field :notes, :string, :length => 4096, :empty => :ok
      field :tagchain, :ref, :model => 'Yabitz::Model::TagChain', :empty => :ok

      CSVFIELDS_S = [:rackunit, :localips, :dnsnames, :hwid]
      CSVFIELDS_M = [:rackunit, :localips, :globalips, :service, :dnsnames, :hwinfo, :hwid, :status]
      CSVFIELDS_L = [:rackunit, :localips, :globalips, :virtualips, :service, :dnsnames, :type, :hwinfo, :memory, :disk, :os, :hwid, :status]
      CSVFIELDS_LL = [:oid, :rackunit, :localips, :globalips, :virtualips, :service, :dnsnames, :type, :hwinfo, :memory, :disk, :os, :hwid, :status]

      def json_meta_fields
        if self.localips_by_id.size > 0
          {:localip => self.localips.first.address}
        else
          {}
        end
      end

      def self.instanciate_mapping(fieldname)
        case fieldname
        when :status, :type, :hwid, :cpu, :memory, :disk, :notes
          {:method => :new, :class => String}
        when :service
          {:method => :get, :class => Yabitz::Model::Service}
        when :parent, :children
          {:method => :get, :class => Yabitz::Model::Host}
        when :os
          {:method => :write_through, :class => Yabitz::Model::OSInformation, :field => :name}
        when :rackunit
          {:method => :query_or_create, :class => Yabitz::Model::RackUnit, :field => :rackunit}
        when :hwinfo
          {:method => :get, :class => Yabitz::Model::HwInformation}
        when :dnsnames
          {:method => :query_or_create, :class => Yabitz::Model::DNSName, :field => :dnsname}
        when :localips, :globalips, :virtualips
          {:method => :query_or_create, :class => Yabitz::Model::IPAddress, :field => :address}
        when :tagchain
          {:method => :always_update, :proc => Proc.new{|this| tc = (this.tagchain or Yabitz::Model::TagChain.new); tc.host = this; tc }, :field => :tagchain}
        else
          raise ArgumentError, "unknown field name '#{fieldname}'"
        end
      end

      def to_s
        self.display_name
      end

      def <=>(other)
        def customcomp(a, b, f, ref=false, list=false)
          c = if ref then f + '_by_id' else f end
          if a.send(c) and (not list or a.send(c).size > 0)
            case
            when (not b.send(c) or (list and b.send(c).size < 1))
              -1
            when list
              a.send(f).first <=> b.send(f).first
            else
              a.send(f) <=> b.send(f)
            end
          elsif b.send(c) and (not list or b.send(c).size > 0)
            1
          else
            0
          end
        end
        val = customcomp(self, other, 'dnsnames', true, true)
        return val unless val == 0
        val = customcomp(self, other, 'localips', true, true)
        return val unless val == 0
        val = customcomp(self, other, 'globalips', true, true)
        return val unless val == 0
        val = customcomp(self, other, 'rackunit', true)
        return val unless val == 0
        val = customcomp(self, other, 'hwid')
        return val unless val == 0
        customcomp(self, other, 'oid')
      end

      def is(*list)
        list.map{|sym| sym.to_s.upcase}.include?(self.status)
      end

      def isnt(*list)
        not list.map{|sym| sym.to_s.upcase}.include?(self.status)
      end

      def display_name
        if self.dnsnames_by_id and self.dnsnames_by_id.size > 0
          return self.dnsnames[0].dnsname
        end
        if self.localips_by_id and self.localips_by_id.size > 0
          return "local:" + self.localips[0].address
        end
        if self.globalips_by_id and self.globalips_by_id.size > 0
          return "global:" + self.globalips[0].address
        end
        if not self.rackunit_by_id.nil?
          return "rackunit:" + self.rackunit.rackunit
        end
        if not self.hwid.nil? and self.hwid.length > 0
          return "hwid:" + self.hwid
        end

        "unknown host oid:" + (self.oid ? self.oid.to_s : " unsaved")
      end

      def hosttype
        Yabitz::HostType.new(self.type)
      end

      def self.normalize_cpu(str)
        return nil if str.nil?
        str.tr('ａ-ｚＡ-Ｚ０-９　．', 'a-zA-Z0-9 .')
      end

      def check_cpu(str)
        str =~ /\A\d+( .*)?\Z/ and str.length < 65
      end

      def self.normalize_memory(str)
        return nil if str.nil?
        tred = str.tr('ａ-ｚＡ-Ｚ０-９　．', 'a-zA-Z0-9 .').delete(' ')
        if tred =~ /\A([.0-9]+)(m|M)(i)?(b|B)?\Z/
          tred.sub!(/(m|M)(i)?(b|B)?/, 'M\\2B')
        elsif tred =~ /\A([.0-9]+)(g|G)(i)?(b|B)?\Z/
          tred.sub!(/(g|G)(i)?(b|B)?/, 'G\\2B')
        elsif tred =~ /\A([.0-9]+)(t|T)(i)?(b|B)?\Z/
          tred.sub!(/(t|T)(i)?(b|B)?/, 'T\\2B')
        end
        tred
      end

      def check_memory(str)
        str =~ /\A[.0-9]{1,5}(M|G|T)(i)?B\Z/ and str.length < 65
      end

      def self.normalize_disk(str)
        return nil if str.nil?
        tred = str.tr('ａ-ｚＡ-Ｚ０-９　．ｘ＊\−＋', 'a-zA-Z0-9 .x*\-+').strip.tr('a-wyz','A-WYZ')
        if tred =~ /\A(HDD|ATA|SATA|SAS|FC|IDE|SCSI|SSD)?\s*([0-9.]+)\s*([mMgGtTpP]i?)B?\s*((x|\*)?\s*([0-9]+))?\s*(RAID(-| )?([0-9A-Z+-]+))?\Z/
          tred = (($1 and not $1.empty?) ? $1 + " " : "") + "#{$2}#{$3}B"
          tred += " x#{$6}" if $4
          tred += " RAID-#{$9}" if $7
        end
        tred
      end

      def check_disk(str)
        str =~ /\A(HDD|ATA|SATA|SAS|FC|SCSI|SSD)? ?[0-9.]+([MGTP]B)( x\d+)?( RAID-[0-9A-Z+-]+)?\Z/ and str.length < 65
      end

      def self.query_tag(tag)
        self.get(TagChain.query(:tagchain => tag).map{|t| t.host_by_id})
      end

      def self.status_title(s)
        case s
        when STATUS_IN_SERVICE
          "稼動中"
        when STATUS_UNDER_DEV
          "準備中"
        when STATUS_NO_COUNT
          "非課金"
        when STATUS_STANDBY
          "待機"
        when STATUS_SUSPENDED
          "停止"
        when STATUS_REMOVING
          "撤去依頼済"
        when STATUS_REMOVED
          "撤去完了"
        when STATUS_MISSING
          "管理対象外"
        when STATUS_OTHER
          "不明"
        else
          raise ArgumentError, "unknown status: #{s}"
        end
      end

      def ipaddresses
        ips_oid = []
        if self.localips_by_id and not self.localips_by_id.empty?
          ips_oid.push(self.localips_by_id)
        end
        if self.globalips_by_id and not self.globalips_by_id.empty?
          ips_oid.push(self.globalips_by_id)
        end
        if self.virtualips_by_id and not self.virtualips_by_id.empty?
          ips_oid.push(self.virtualips_by_id)
        end
        Yabitz::Model::IPAddress.get(ips_oid)
      end

      def self.build_csv(fields, hosts)
        ret_table = []
        fields.each do |field|
          maxlen = field.to_s.length
          vals = [field.to_s.upcase]
          hosts.each do |host|
            v = [host.send(field)].flatten.map(&:to_s).join(' ')
            maxlen = v.length if v.length > maxlen
            vals.push(v)
          end
          fmt = '%-' + (maxlen + 1).to_s + 's'
          ret_table.push(vals.map{|v| fmt % v})
        end
        require 'csv'
        ret_table.transpose.map(&:to_csv).join
      end

      def self.build_raw_csv(fields, hosts)
        require 'csv'
        ret_lines = [fields.map{|f| f.to_s.upcase}.to_csv]
        hosts.each do |h|
          ret_lines.push(fields.map{|f| [h.send(f)].flatten.map(&:to_s).join(' ')}.to_csv)
        end
        ret_lines.join
      end

      def self.build_raw_csv_burst_llfields(hosts)
        require 'csv'
        CSV.generate do |csv|
          csv << CSVFIELDS_LL.map(&:upcase)
          hosts.each do |h|
            csv << [h.oid.to_s,
                    h.rackunit.to_s,
                    h.localips.map(&:to_s).join(' '),
                    h.globalips.map(&:to_s).join(' '),
                    h.virtualips.map(&:to_s).join(' '),
                    h.service.to_s,
                    h.dnsnames.map(&:to_s).join(' '),
                    h.type,
                    h.hwinfo.to_s,
                    h.memory.to_s,
                    h.disk.to_s,
                    h.os.to_s,
                    h.hwid,
                    h.status]
          end
        end
      end
    end
  end
end
