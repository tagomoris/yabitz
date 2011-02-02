# -*- coding: utf-8 -*-

module Yabitz::Plugin
  module StandardRack42U
    def self.plugin_type
      :racktype
    end
    def self.plugin_priority
      0
    end
    # This plugin module is for example, and NOT TESTED.

    def self.name
      'STANDARD42U'
    end

    def self.datacenter
      'SOMEWHARE'
    end

    def self.rack_label_pattern
      /\A[a-zA-Z][0-9]{2}-(0[1-9]|[1-3][0-9]|4[012])[fr]?\Z/
    end

    def self.rackunit_label_pattern
      /\A[a-zA-Z][0-9]{2}\Z/ # rack number: alphabet + [num]x2
    end

    def self.rack_label(rackunit_label)
      rackunit_label[0, 3]
    end

    def self.dividing(rackunit_label)
      require_relative '../misc/racktype'
      case
      when rackunit_label =~ /\df\Z/
        Yabitz::RackTypes::DIVIDING_HALF_FRONT
      when rackunit_label =~ /\dr\Z/
        Yabitz::RackTypes::DIVIDING_HALF_REAR
      else
        Yabitz::RackTypes::DIVIDING_FULL
      end
    end

    def self.rack_label_example
      'A01'
    end

    def self.rackunit_label_example
      'A01-42(f/r)'
    end

    def self.upper_rackunit_labels(from, num)
      from =~ /\A([a-zA-Z][0-9]{2}-)(0[1-9]|[1-3][0-9]|4[012])([fr]?)\Z/
      rack_label = $1
      position = $2.to_i
      form = ($3 || '')
      list = []
      (1..num).each do |up|
        list.push(rack_label + ('%02d' % (position + up)) + form)
      end
      list
    end

    def self.rackunit_space_list(rack_label)
      list = []
      unit = 42
      while unit > 0
        full = rack_label + ("-%02d" % i)
        list.push([full, full + 'f', full + 'r'])
        unit = unit - 1
      end
      list
    end

    def self.rack_display_template
      <<EOT
%table
  - Yabitz::RackTypes.search(@rack.label).rackunit_space_list(@rack.label).each do |full, front, rear|
    %tr
      %td{:style => 'border: 2px solid black;'}&= full
      - if @units[full]
        - host = @units[full]
        %td{:colspan => 2, :style => 'background-color: #8888FF; border: 2px solid black;'}
          %div&= host.display_name + ' / ' + (host.hwinfo ? host.hwinfo.units : "unknown")
          - if host.children and host.children.size > 0
            %div&= host.children.map(&:display_name).join(", ")
      - elsif @units[front] or @units[rear]
        - if @units[front]
          - host = @units[front]
          %td{:style => 'background-color: #8888FF; border: 2px solid black;'}
            %div&= host.display_name + ' / ' + (host.hwinfo ? host.hwinfo.units : "unknown")
            - if host.children and host.children.size > 0
              %div&= host.children.map(&:display_name).join(", ")
        - else
          %td{:style => 'background-color: #8888FF; border: 2px solid black;'}
            %div&= '-'
        - if @units[rear]
          - host = @units[rear]
          %td{:style => 'background-color: #8888FF; border: 2px solid black;'}
            %div&= host.display_name + ' / ' + (host.hwinfo ? host.hwinfo.units : "unknown")
            - if host.children and host.children.size > 0
              %div&= host.children.map(&:display_name).join(", ")
        - else
          %td{:style => 'background-color: #8888FF; border: 2px solid black;'}
            %div&= '-'
      - else
        %td{:colspan => 2, :style => 'background-color: #8888FF; border: 2px solid black;'}
          %div&= '-'
EOT
    end
  end
end
