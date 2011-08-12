# -*- coding: utf-8 -*-

require_relative '../model'

module Yabitz::Checker
  def self.check
    #TODO: write to check ipsegments/rack

    hosts = Yabitz::Model::Host.all
    services = Yabitz::Model::Service.all
    dnsnames = Yabitz::Model::DNSName.all
    ipaddrs = Yabitz::Model::IPAddress.all
    rackunits = Yabitz::Model::RackUnit.all
    contacts = Yabitz::Model::Contact.all
    bricks = Yabitz::Model::Brick.all

    hwid_hosts = {}

    host_relation_mismatches = []
    type_and_hwinfo_mismatches = []
    parent_rackunit_mismatches = []
    parent_hwid_mismatches = []

    hwid_duplications = []
    hwid_missings = []
    dnsname_duplications = []
    rackunit_duplications = []
    rackunit_missings = []
    ipaddress_duplications = []
    
    services_without_contacts = []

    bricks_hwid_duplications = []
    bricks_serial_duplications = []
    bricks_without_hwid_serial = []
    bricks_status_hwid_host_mismatches = []
    bricks_status_heap_mismatches = []

    def self.working?(host)
      [
       Yabitz::Model::Host::STATUS_IN_SERVICE,
       Yabitz::Model::Host::STATUS_NO_COUNT,
      ].include?(host.status)
    end

    def self.alive?(host)
      [
       Yabitz::Model::Host::STATUS_IN_SERVICE,
       Yabitz::Model::Host::STATUS_UNDER_DEV,
       Yabitz::Model::Host::STATUS_NO_COUNT,
       Yabitz::Model::Host::STATUS_STANDBY,
       Yabitz::Model::Host::STATUS_SUSPENDED,
      ].include?(host.status)
    end

    def self.hw_assigned?(host)
      [
       Yabitz::Model::Host::STATUS_IN_SERVICE,
       Yabitz::Model::Host::STATUS_NO_COUNT,
       Yabitz::Model::Host::STATUS_STANDBY,
       Yabitz::Model::Host::STATUS_SUSPENDED,
       Yabitz::Model::Host::STATUS_REMOVING,
      ].include?(host.status)
    end

    def self.exist?(host)
      host.status != Yabitz::Model::Host::STATUS_REMOVED
    end

    hosts.each do |host|
      unless host.hwid.nil? or host.hwid.empty?
        hwid_hosts[host.hwid] ||= []
        hwid_hosts[host.hwid].push(host)
      else
        hwid_missings.push(host) if hw_assigned?(host)
      end

      next unless host.hosttype.hypervisor? or host.hosttype.virtualmachine?

      type = host.hosttype

      # check: type and parent/children mismatch
      if type.virtualmachine? and working?(host)
        unless not host.parent.nil? and working?(host.parent) and host.parent.hosttype.hypervisor? and host.hosttype.hypervisor == host.parent.hosttype
          host_relation_mismatches.push(host)
        end
      end
      # check: type and hwinfo(virtualized?) mismatch
      if type.virtualmachine? and working?(host)
        unless host.hwinfo and host.hwinfo.virtualized?
          type_and_hwinfo_mismatches.push(host)
        end
      end
      # check: mismatch rackunit/hwid bitween parent-children
      if type.virtualmachine? and host.parent_by_id and alive?(host)
        if host.rackunit_by_id and host.rackunit_by_id != host.parent.rackunit_by_id
          parent_rackunit_mismatches.push(host)
        end
        if host.hwid and not host.hwid.empty? and host.hwid != host.parent.hwid
          parent_hwid_mismatches.push(host)
        end
      elsif not host.rackunit_by_id
        rackunit_missings.push(host) if hw_assigned?(host)
      end
    end

    # check: hwid with multi-host (not parent-children pattern)
    hwid_hosts.keys.each do |k|
      if hwid_hosts[k].size > 1 and hwid_hosts[k].select{|h| exist?(h) and not h.hosttype.virtualmachine?}.size > 1
        hwid_duplications.push([k, hwid_hosts[k].select{|h| exist?(h) and not h.hosttype.virtualmachine?}])
      end
    end
    # check: dnsname with multi-host
    dnsnames.each do |d|
      if d.hosts_by_id.size > 1 and d.hosts.select{|h| exist?(h)}.size > 1
        dnsname_duplications.push(d)
      end
    end
    # check: rackunit with multi-host (not parent-children pattern)
    rackunits.each do |r|
      if r.hosts_by_id.size > 1 and r.hosts.select{|h| exist?(h) and not h.hosttype.virtualmachine?}.size > 1
        rackunit_duplications.push(r)
      end
    end
    # check: ipaddress with multi-host (not virtualip)
    ipaddrs.each do |i|
      if i.hosts_by_id.size > 1 and i.hosts.select{|h| exist?(h) and not h.virtualips_by_id.include?(i.oid)}.size > 1
        ipaddress_duplications.push(i)
      end
    end

    # check: serivce without contact
    services.each do |s|
      if s.contact.nil?
        services_without_contacts.push(s)
      end
    end

    bricks_hwid = {}
    bricks_serial = {}

    bricks.each do |brick|
      # for check: 2 or more bricks has same hwid
      if brick.hwid and not brick.hwid.empty?
        bricks_hwid[brick.hwid] ||= []
        bricks_hwid[brick.hwid].push(brick)
      end

      # for check: 2 or more bricks has same serial
      if brick.serial and not brick.serial.empty?
        bricks_serial[brick.serial] ||= []
        bricks_serial[brick.serial].push(brick)
      end

      # check: bricks without hwid and/or serial
      unless (brick.hwid and not brick.hwid.empty?) or (brick.serial and not brick.serial.empty?)
        bricks_without_hwid_serial.push(brick) 
      end
      
      # check: bricks in (IN_USE, but thats hwid not connected to host), (STOCK/SPARE/REPAIR/BROKEN, but connected to host)
      if brick.status == Yabitz::Model::Brick::STATUS_IN_USE
        if brick.hwid and (not hwid_hosts[brick.hwid] or hwid_hosts[brick.hwid].length == 0)
          bricks_status_hwid_host_mismatches.push(brick)
        end
      else
        if brick.hwid and hwid_hosts[brick.hwid] and hwid_hosts[brick.hwid].length > 0
          bricks_status_hwid_host_mismatches.push(brick)
        end
      end

      # check: bricks in STOCK/SPARE/BROKEN but without heap
      if [Yabitz::Model::Brick::STATUS_STOCK, Yabitz::Model::Brick::STATUS_SPARE, Yabitz::Model::Brick::STATUS_BROKEN].include?(brick.status)
        if not brick.heap or brick.heap.empty?
          bricks_status_heap_mismatches.push(brick)
        end
      end
    end

    # check: 2 or more bricks has same hwid
    bricks_hwid_duplications = bricks_hwid.values.select{|ary| ary.length > 1}

    # check: 2 or more bricks has same serial
    bricks_serial_duplications = bricks_serial.values.select{|ary| ary.length > 1}

    {
      :host_relation_mismatches => host_relation_mismatches,
      :type_and_hwinfo_mismatches => type_and_hwinfo_mismatches,
      :parent_rackunit_mismatches => parent_rackunit_mismatches,
      :parent_hwid_mismatches => parent_hwid_mismatches,
      :hwid_duplications => hwid_duplications,
      :hwid_missings => hwid_missings,
      :dnsname_duplications => dnsname_duplications,
      :rackunit_duplications => rackunit_duplications,
      :rackunit_missings => rackunit_missings,
      :ipaddress_duplications => ipaddress_duplications,
      :services_without_contacts => services_without_contacts,
      :bricks_hwid_duplications => bricks_hwid_duplications,
      :bricks_serial_duplications => bricks_serial_duplications,
      :bricks_without_hwid_serial => bricks_without_hwid_serial,
      :bricks_status_hwid_host_mismatches => bricks_status_hwid_host_mismatches,
      :bricks_status_heap_mismatches => bricks_status_heap_mismatches,
    }
  end

  def self.systemcheck
    # check: cross reference mismatch (ref and reflist)
    # check: uniqueness of ipaddress, rackunit, dnsname, etc
    # check: type and parent/children mismatch
    if type.virtualmachine? and not host.parent.children_by_id.include?(host.oid)
      relation_mismatches_from_child.push(host)
    end
    # check: mismatch parent-children reference mismatch
    if type.hypervisor? and host.children.size > 0
      unless host.children.inject(true){|r, c| r and c.parent_by_id == host.oid}
        relation_mismatches_from_parent.push(host)
      end
    end
  end
end
