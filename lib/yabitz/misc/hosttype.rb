# -*- coding: utf-8 -*-

module Yabitz
  class HostType
    BLICK = :blick
    NETWORK = :network
    HV = :hypervisor
    VM = :virtualmachine

    TYPES = [
             {
               :name => 'real',
               :type => BLICK,
               :product => 'server',
             },
             {
               :name => 'switch',
               :type => NETWORK,
               :product => 'other',
             },
             {
               :name => 'Xen(Dom0)',
               :type => HV,
               :product => 'xen',
             },
             {
               :name => 'Xen(DomU)',
               :type => VM,
               :product => 'xen',
             },
             {
               :name => 'Jail(Host)',
               :type => HV,
               :product => 'bsd',
             },
             {
               :name => 'Jail(Guest)',
               :type => VM,
               :product => 'bsd',
             },
            ]

    def self.names
      TYPES.map{|t| t[:name]}
    end

    def initialize(type)
      @typedata = TYPES.select{|t| t[:name] == type}.first
      raise ArgumentError, "unknown type name #{type}" unless @typedata
    end

    def ==(other)
      self.name == other.name
    end

    def name
      @typedata[:name]
    end

    def host?
      not [:network].include?(@typedata[:type])
    end

    def hypervisor?
      @typedata[:type] == HV
    end

    def virtualmachine?
      @typedata[:type] == VM
    end

    def hypervisor
      raise TypeError, "hypervisor question allowed with type VM" unless @typedata[:type] == VM
      self.class.new(TYPES.select{|t| t[:type] == HV and t[:product] == @typedata[:product]}.first[:name])
    end
  end
end
