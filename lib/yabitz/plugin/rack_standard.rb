# -*- coding: utf-8 -*-

module Yabitz::Plugin
  module StandardRack42U
    def self.plugin_type
      :racktype
    end
    def self.plugin_priority
      1
    end
    # This plugin module is for example, and NOT TESTED.

    def self.name
      'STANDARD42U'
    end

    def self.datacenter
      'SOMEWHARE'
    end

    def self.rack_label_pattern
      /\A[a-zA-Z][0-9]{2}\Z/ # rack number: alphabet + [num]x2
    end

    def self.rackunit_label_pattern
      /\A[a-zA-Z][0-9]{2}-(0[1-9]|[1-3][0-9]|4[012])[fr]?\Z/
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
        full = rack_label + ("-%02d" % unit)
        list.push([full, full + 'f', full + 'r'])
        unit = unit - 1
      end
      list
    end

    def self.rack_display_template
      <<EOT
- style_blank = 'text-align: center; background-color: #e0e0e0; border: 2px solid black;'
- style_filled = 'padding-left: 5px; background-color: #DDDDFF; border: 2px solid black;'
- style_disp = 'font-weight: bold;'
- style_info = 'font-size: 80%;'
- def disp(host); host.display_name + (host.parent ? '' : ' / ' + (host.hwid ? host.hwid : '')) ; end
- def info(host); '(' + host.service.name +  (host.localips.size > 0 ? ', ' + host.localips.first.address : '') + ')'; end
- racktype = Yabitz::RackTypes.search(@rack.label)
%table{:width => '100%', :style => 'witdh: 100%;'}
  %tr
    %td{:width => '10%', :style => style_blank} unit
    %td{:width => '45%', :align => 'center', :style => style_blank} FRONT
    %td{:width => '45%', :align => 'center', :style => style_blank} REAR
  - racktype.rackunit_space_list(@rack.label).each do |full, front, rear|
    %tr
      %td{:style => 'border: 2px solid black;'}&= full
      - if @units[full]
        - host = @units[full]
        - if @units[racktype.upper_rackunit_labels(full, 1).first] != host
          %td{:colspan => 2, :rowspan => (host.hwinfo ? host.hwinfo.unit_height : 1), :style => style_filled}
            %div
              %span{:style => style_disp}&= disp(host)
              %span{:style => style_info}&= info(host)
            - if host.children and host.children.size > 0
              - host.children.each do |c|
                %li
                  %span{:style => style_disp}&= disp(c)
                  %span{:style => style_info}&= info(c)
      - elsif @units[front] or @units[rear]
        - if @units[front]
          - host = @units[front]
          - if @units[racktype.upper_rackunit_labels(front, 1).first] != host
            %td{:rowspan => (host.hwinfo ? host.hwinfo.unit_height : 1), :style => style_filled}
              %div
                %span{:style => style_disp}&= disp(host)
                %span{:style => style_info}&= info(host)
              - if host.children and host.children.size > 0
                - host.children.each do |c|
                  %li
                    %span{:style => style_disp}&= disp(c)
                    %span{:style => style_info}&= info(c)
        - else
          %td{:style => style_blank}
            %div&= '-'
        - if @units[rear]
          - host = @units[rear]
          - if @units[racktype.upper_rackunit_labels(rear, 1).first] != host
            %td{:rowspan => (host.hwinfo ? host.hwinfo.unit_height : 1), :style => style_filled}
              %div
                %span{:style => style_disp}&= disp(host)
                %span{:style => style_info}&= info(host)
              - if host.children and host.children.size > 0
                - host.children.each do |c|
                  %li
                    %span{:style => style_disp}&= disp(c)
                    %span{:style => style_info}&= info(c)
        - else
          %td{:style => style_blank}
            %div&= '-'
      - else
        %td{:colspan => 2, :style => style_blank}
          %div&= '-'
EOT
    end
  end
end
