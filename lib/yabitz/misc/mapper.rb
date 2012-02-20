# -*- coding: utf-8 -*-

module Yabitz
  module Mapper
    class Generator
      def initialize(this, opts)
        @this = this
        @method = opts[:method]
        @class ||= opts[:class]
        @proc ||= opts[:proc]
        @field ||= opts[:field]

        case @method
        when :new, :get, :query_or_create, :write_through
          raise ArgumentError, "missing class" unless @class

          if @method == :get 
            raise ArgumentError, "invalid class specified for get" unless @class.respond_to?(:get)
          end

          if @method == :query_or_create or @method == :write_through
            raise ArgumentError, "missing field"  unless @class.respond_to?(:query_or_create) and @field
          end
        when :always_update
          raise ArgumentError, "missing proc" unless @proc and @proc.respond_to?(:call)
          raise ArgumentError, "missing this" unless @this
          raise ArgumentError, "missing field" unless @field
        when :boolparser
          # ok.
        else
          raise ArgumentError, "unknown update method type '#{@method}'"
        end
      end

      def call(vals, opt_val=nil)
        return self.call_once(vals) unless vals.respond_to?(:map)

        objs = vals.map{|v| self.call_once(v)}
        if opt_val
          objs.push(self.call_once(opt_val))
        end
        objs
      end

      def call_once(val)
        case @method
        when :new # for String, and others
          @class.new(val)
        when :boolparser
          valstr = val.to_s
          valstr.casecmp('true') == 0 or valstr.casecmp('yes') == 0 or valstr == '1'
        when :get # for Stratum::Model, and val expected as string of oid
          @class.get(val.to_i)
        when :query_or_create
          @class.query_or_create(@field => val)
        when :write_through # for hwtype, osinfo
          @class.query_or_create(@field => val).to_s
        when :always_update # for tagchain
          obj = @proc.call(@this)
          obj.send(@field.to_s + '=', val)
          obj.respond_to?(:save) and obj.save
          obj
        else
          raise ArgumentError, "unknown update method type '#{@method}'"
        end
      end
    end

    def member_generator(fieldname)
      Yabitz::Mapper::Generator.new(self, self.class.instanciate_mapping(fieldname))
    end

    def map_value(field, request)
      generator = self.member_generator(field)
      value_keys = request.params.keys.select{|x| x =~ /\Avalue(\d+|_new)?\Z/}

      if value_keys.size == 1 and value_keys.first == 'value'
        newvalue = request.params['value'].strip
        if newvalue.size > 0
          generator.call(newvalue)
        else
          nil
        end
      else
        vkeys = value_keys.select{|k| k =~ /\Avalue\d+\Z/}.map{|k| k =~ /\Avalue(\d+)\Z/ and $1.to_i}.sort()
        new_values_s = vkeys.map{|i| request.params["value#{i}"].strip}.select{|vstr| vstr.size > 0}
        addvalue = request.params["value_new"].strip

        if request.params['maptype'] and request.params['maptype'] == 'list'
          if addvalue and addvalue.size > 0
            new_values_s.push(addvalue)
          end
          generator.call_once(new_values_s)
        else
          add_value_s = (addvalue && addvalue.size > 0) ? addvalue : nil
          generator.call(new_values_s, add_value_s)
        end
      end
    end
  end
end
