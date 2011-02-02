# -*- coding: utf-8 -*-

require_relative '../model'
require_relative './errors'
module Yabitz
  module Charging
    # punits means 'physical units', cunits means 'calculated units'
    SummaryInitializer = lambda { {:hosts => 0, :punits => 0.0, :cunits => 0.0} }

    def self.content_init_perspectives(content)
      service_perspective = {}
      content.services.each do |s|
        service_perspective[s.oid] = SummaryInitializer.call
      end
      service_perspective[:total] = SummaryInitializer.call
      service_perspective
    end

    def self.summary_init_perspectives
      status_perspective = {}
      Yabitz::Model::Host::STATUS_LIST.each do |status|
        status_perspective[status] = SummaryInitializer.call
      end
      status_perspective[:total] = SummaryInitializer.call

      type_perspective = {}
      Yabitz::HostType.names.each do |type|
        type_perspective[type] = SummaryInitializer.call
      end
      type_perspective[:total] = SummaryInitializer.call

      charging_perspective = {}
      Yabitz::Model::Content::CHARGING_LABELS.each do |label|
        charging_perspective[label] = SummaryInitializer.call
      end
      charging_perspective[:total] = SummaryInitializer.call

      depts_perspective = {}
      Yabitz::Model::Dept.all.each do |dept|
        depts_perspective[dept.oid] = SummaryInitializer.call
      end
      
      contents_perspective = {}
      Yabitz::Model::Content.all.each do |content|
        contents_perspective[content.oid] = SummaryInitializer.call
      end
      
      return status_perspective, type_perspective, charging_perspective, depts_perspective, contents_perspective
    end

    def self.count_elements(host)
      hosttype = host.hosttype

      if hosttype.hypervisor?
        if host.hwinfo.nil?
          [1, 1.0, 0.0]
        else
          [1, host.hwinfo.calcunits.to_f, 0.0]
        end
      elsif hosttype.virtualmachine?
        raise Yabitz::InconsistentDataError, "parent unsetted!!!! about:#{host.display_name}" unless host.parent
        if host.parent.hwinfo.nil?
          [1, 0.0, (1.0 / host.parent.children_by_id.size.to_f)]
        else
          [1, 0.0, (host.parent.hwinfo.calcunits.to_f * 1.0 / host.parent.children_by_id.size.to_f)]
        end
      else
        if host.hwinfo.nil?
          [1, 1.0, 1.0]
        else
          [1, host.hwinfo.calcunits.to_f, host.hwinfo.calcunits.to_f]
        end
      end
    end

    def self.calculate_content(content)
      service_perspective = self.content_init_perspectives(content)

      content.services.each do |service|
        Yabitz::Model::Host.query(:service => service).each do |host|
          next unless host.status == Yabitz::Model::Host::STATUS_IN_SERVICE

          h,p,c = self.count_elements(host)

          service_perspective[service.oid][:hosts] += h
          service_perspective[service.oid][:punits] += p
          service_perspective[service.oid][:cunits] += c
          service_perspective[:total][:hosts] += h
          service_perspective[:total][:punits] += p
          service_perspective[:total][:cunits] += c
        end
      end
      service_perspective
    end

    def self.calculate(hosts)
      status, types, chargings, depts, contents = self.summary_init_perspectives

      hosts.each do |host|
        status[host.status][:hosts] += 1
        status[:total][:hosts] += 1

        types[host.type][:hosts] += 1
        types[:total][:hosts] += 1

        next unless host.status == Yabitz::Model::Host::STATUS_IN_SERVICE

        h,p,c = self.count_elements(host)

        charging = host.service.content.charging

        chargings[charging][:hosts] += h
        chargings[charging][:punits] += p
        chargings[charging][:cunits] += c unless charging == Yabitz::Model::Content::CHARGING_NO_COUNT
        chargings[:total][:hosts] += h
        chargings[:total][:punits] += p
        chargings[:total][:cunits] += c unless charging == Yabitz::Model::Content::CHARGING_NO_COUNT

        depts[host.service.content.dept.oid][:hosts] += h
        depts[host.service.content.dept.oid][:punits] += p
        depts[host.service.content.dept.oid][:cunits] += c unless charging == Yabitz::Model::Content::CHARGING_NO_COUNT

        contents[host.service.content.oid][:hosts] += h
        contents[host.service.content.oid][:punits] += p
        contents[host.service.content.oid][:cunits] += c unless charging == Yabitz::Model::Content::CHARGING_NO_COUNT
      end

      return status, types, chargings, depts, contents
    end
  end
end

