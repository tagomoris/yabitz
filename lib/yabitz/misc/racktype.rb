# -*- coding: utf-8 -*-

module Yabitz::RackTypes
  DIVIDING_FULL = 'FULL'
  DIVIDING_HALF_FRONT = 'FRONT'
  DIVIDING_HALF_REAR = 'REAR'
  DIVIDINGS = [DIVIDING_FULL, DIVIDING_HALF_FRONT, DIVIDING_HALF_REAR].freeze

  def self.list
    Yabitz::Plugin.get(:racktype)
  end
  
  def self.default
    raise RuntimeError, "no one rack type exists." unless self.list.first
    self.list.first
  end

  def self.search(rack_label)
    self.list.each do |p|
      return p if rack_label =~ p.rack_label_pattern
    end
    nil
  end

  def self.search_by_unit(rackunit_label)
    self.list.each do |p|
      Kernel.p p.rackunit_label_pattern
      return p if rackunit_label =~ p.rackunit_label_pattern
    end
    nil
  end
end
