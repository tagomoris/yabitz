# -*- coding: utf-8 -*-

require 'stratum'

module Yabitz
  module Logging
    def self.log_auth(username, msg, oid=nil, sourceip='')
      Stratum.conn do |c|
        st = c.prepare("INSERT INTO auth_log SET username=?,msg=?,oid=?,sourceip=?")
        st.execute(username, msg, oid, sourceip)
      end
    end
  end
end
