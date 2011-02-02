# -*- coding: utf-8 -*-

require 'ldap'
module Yabitz; end

module Yabitz::LDAPHandler
  def self.nodes(dn)
    dn.split(',').map{|ent| ent.split('=')}
  end

  def self.connection(server, port)
    conn = LDAP::Conn.new(server, port)
    conn.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
    conn
  end

  def self.try_auth(dn, pass)
    server, port, sys_username, sys_password = Yabitz.config.ldapparams()
    conn = self.connection(server, port)
    begin
      conn.bind(dn, pass)
      return conn.bound?
    rescue LDAP::ResultError
      return false
    ensure
      conn.unbind
    end
  end

  def self.search(search_path_list, filter, &block)
    server, port, username, password = Yabitz.config.ldapparams()
    conn = self.connection(server, port.to_i)
    conn.bind(username, password)

    results = []
    search_path_list.each do |search_path|
      result_set = conn.search2(search_path, LDAP::LDAP_SCOPE_SUBTREE, filter)
      result_set.each do |ent|
        if not block_given? or yield ent
          results.push(ent)
        end
      end
    end
    conn.unbind
    results
  end

  def self.get_child_nodes(conn, search_dn)
    now_top_ou = self.nodes(search_dn).first.last
    ou_list = conn.search2(search_dn, LDAP::LDAP_SCOPE_ONELEVEL, '(ou=*)').select{|ent| ent['name'].first != now_top_ou}
    cn_list = conn.search2(search_dn, LDAP::LDAP_SCOPE_ONELEVEL, '(cn=*)')
    [ou_list, cn_list]
  end

  def self.find_cn_recursive(conn, path_dn, get_multi=false, lambda=Proc.new)
    oulist, cnlist = self.get_child_nodes(conn, path_dn)
    hit_set = []
    cnlist.each do |ent|
      if lambda.call(ent)
        return ent unless get_multi
        hit_set.push(ent)
      end
    end
    oulist.each do |ent|
      result = self.find_cn_recursive(conn, "ou=#{ent['name'].first.force_encoding('utf-8')}," + path_dn, get_multi, lambda)
      if not get_multi and result
        return result
      end
      hit_set.push(*result)
    end
    return nil unless get_multi
    hit_set
  end

  def self.find_by(search_paths, lambda=Proc.new)
    server, port, checker_name, checker_pass = Yabitz.config.ldapparams()
    conn = self.connection(server, port)
    conn.bind(checker_name, checker_pass)

    entries = []
    search_paths.each do |path_dn|
      ents = self.find_cn_recursive(conn, path_dn, true, lambda)
      entries.push(*ents) if ents.size > 0
    end
    conn.unbind
    entries
  end

  def self.find_all_entries(search_paths)
    self.find_by(search_paths){|ent| ent}
  end

  def self.find_serial_by(search_paths, list, lambda=Proc.new)
    entries = self.find_all_entries(search_paths)
    list.map{|i| entries.select{|ent| lambda.call(i,ent)}.first}.compact
  end
end
