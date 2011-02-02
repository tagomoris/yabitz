# -*- coding: utf-8 -*-

module Yabitz
  module RefUpdator
    def self.update(target_oid, prevalue, postvalue, fieldlist)
      prevalues = [prevalue].flatten.select{|o| o.respond_to?(:oid)}
      postvalues = [postvalue].flatten.select{|o| o.respond_to?(:oid)}
      return if prevalues.size < 1 and postvalues.size < 1

      removed_values = prevalues.select{|pre| not postvalues.map(&:oid).include?(pre.oid)}
      pushed_values = postvalues.select{|post| not prevalues.map(&:oid).include?(post.oid)}

      removed_values.each do |r|
        updated = false
        fieldlist.each do |field|
          next unless r.respond_to?(field)

          f = field.to_s + '_by_id'
          if r.send(f).is_a?(Array)
            r.send(f + '=', r.send(f).select{|i| i != target_oid})
          else
            unless r.send(f) == target_oid
              raise RuntimeError, "invalid operation with object referenced from other oid: #{r.class.name}/#{r.oid}, operated from #{target_oid}"
            end
            r.send(f + '=', nil)
          end
          updated = true
        end
        r.save if updated
      end
      pushed_values.each do |p|
        updated = false
        fieldlist.each do |field|
          next unless p.respond_to?(field)

          f = field.to_s + '_by_id'
          if p.send(f).is_a?(Array)
            p.send(f + '=', p.send(f).select{|i| i != target_oid} + [target_oid])
          else
            if p.send(f)
              raise RuntimeError, "invalid operation with object referenced from other oid: #{p.class.name}/#{p.oid}, operated from #{target_oid}"
            end
            p.send(f + '=', target_oid)
          end
          updated = true
        end
        p.save if updated
      end
    end
  end
end
