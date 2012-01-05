# -*- coding: utf-8 -*-

require 'sinatra/base'

require 'haml'
require 'sass'

require 'cgi'
require 'digest/sha1'
require 'json'
require 'ipaddr'

require_relative 'misc/init'

########### ldap try for osx module loading
if Yabitz.config.name == :development and Yabitz.config.ldapparams and not Yabitz.config.ldapparams.empty?
  require 'ldap'
  ldap = Yabitz.config.ldapparams
  LDAP::Conn.new(ldap[0], ldap[1])
end
###########

require_relative './helper'

require_relative 'misc/opetag_generator'
require_relative 'misc/search'
require_relative 'misc/charge'
require_relative 'misc/checker'

class Yabitz::Application < Sinatra::Base
  BASIC_AUTH_REALM = "Yabitz Authentication"
  
  HTTP_STATUS_OK = 200
  HTTP_STATUS_FORBIDDEN = 403
  HTTP_STATUS_NOT_FOUND = 404
  HTTP_STATUS_NOT_ACCEPTABLE = 406
  HTTP_STATUS_CONFLICT = 409

  helpers Sinatra::AuthenticateHelper
  helpers Sinatra::PartialHelper
  helpers Sinatra::HostCategorize
  helpers Sinatra::LinkGenerator
  helpers Sinatra::EscapeHelper
  helpers Sinatra::ValueComparator

  # configure :production do
  # end
  # configure :test do 
  # end

  configure do
    set :public_folder, File.dirname(__FILE__) + '/../../public'
    set :views, File.dirname(__FILE__) + '/../../view'
    set :haml, {:format => :html5}

    system_boot_str = ""
    open('|who -b') do |io|
      system_boot_str = io.readlines.join
    end
    use Rack::Session::Cookie, :expire_after => 3600*48, :secret => Digest::SHA1.hexdigest(system_boot_str)
  end

  Yabitz::Plugin.get(:middleware_loader).each do |plugin|
    plugin.load_middleware(self)
  end
  
  before do 
  end

  after do
    # when auth failed, unread content body make error log on Apache
    request.body.read # and throw away to somewhere...
  end

  ### 認証 ###
  get '/ybz/authenticate/login' do
    protected!
    if request.referer == '/'
      redirect '/ybz/services'
    end
    redirect request.referer
  end

  get '/ybz/authenticate/logout' do
    session[:username] = ""
    redirect '/ybz/services'
  end

  get '/ybz/authenticate/basic' do
    protected!
    "ok"
  end

  post '/ybz/authenticate/form' do
    pair = request.params().values_at(:username, :password)
    user = Yabitz::Model::AuthInfo.authenticate(*pair, request.ip)
    unless user
      response['WWW-Authenticate'] = %(Basic realm=BASIC_AUTH_REALM)
      throw(:halt, [401, "Not Authorized\n"])
    end
    "ok"
  end

  ### smart search ###
  get %r!/ybz/smartsearch(\.json|\.csv)?! do |ctype|
    authorized?
    searchparams = request.params['keywords'].strip.split(/\s+/)
    @page_title = "簡易検索 結果"
    @service_results = []
    @results = []
    @brick_results = []
    searchparams.each do |keyword|
      search_props = Yabitz::SmartSearch.kind(keyword)
      search_props.each do |type, name, model|
        if model == :service
          @service_results.push([name + ": " + keyword, Yabitz::SmartSearch.search(type, keyword)])
        elsif model == :brick
          @brick_results.push([name + ": " + keyword, Yabitz::SmartSearch.search(type, keyword)])
        else
          @results.push([name + ": " + keyword, Yabitz::SmartSearch.search(type, keyword)])
        end
      end
    end

    Stratum.preload(@results.map(&:last).flatten, Yabitz::Model::Host) if @results.size > 0 and @results.map(&:last).flatten.size > 0
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      # ignore service/brick list for json
      @results.map(&:last).flatten.to_json
    when '.csv'
      response['Content-Type'] = 'text/csv'
      # ignore service/brick list for csv
      Yabitz::Model::Host.build_raw_csv(Yabitz::Model::Host::CSVFIELDS_LL, @results.map(&:last).flatten)
    else
      @copypastable = true
      @service_unselectable = true
      @brick_unselectable = true
      haml :smartsearch, :locals => {:cond => searchparams.join(' ')}
    end
  end

  ### detailed search ###
  get %r!/ybz/search(\.json|\.csv)?! do |ctype|
    authorized?
    
    @page_title = "ホスト検索"
    @hosts = nil
    andor = 'AND'
    conditions = []
    ex_andor = 'AND'
    ex_conditions = []
    if request.params['andor']
      andor = (request.params['andor'] == 'OR' ? 'OR' : 'AND')
      request.params.keys.map{|k| k =~ /\Acond(\d+)\Z/; $1 ? $1.to_i : nil}.compact.sort.each do |i|
        next if request.params["value#{i}"].nil? or request.params["value#{i}"].empty?
        search_value = request.params["value#{i}"].strip
        conditions.push([request.params["field#{i}"], search_value])
      end
      ex_andor = (request.params['ex_andor'] == 'OR' ? 'OR' : 'AND')
      request.params.keys.map{|k| k =~ /\Aex_cond(\d+)\Z/; $1 ? $1.to_i : nil}.compact.sort.each do |i|
        next if request.params["ex_value#{i}"].nil? or request.params["ex_value#{i}"].empty?
        ex_search_value = request.params["ex_value#{i}"].strip
        ex_conditions.push([request.params["ex_field#{i}"], ex_search_value])
      end
      @hosts = Yabitz::DetailSearch.search(andor, conditions, ex_andor, ex_conditions)
    end

    Stratum.preload(@hosts, Yabitz::Model::Host) if @hosts;
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @hosts.to_json
    when '.csv'
      response['Content-Type'] = 'text/csv'
      Yabitz::Model::Host.build_raw_csv(Yabitz::Model::Host::CSVFIELDS_LL, @hosts)
    else
      counter = 0
      keyvalues = []
      conditions.each{|f,v| keyvalues.push("cond#{counter}=#{counter}&field#{counter}=#{f}&value#{counter}=#{v}"); counter += 1}
      counter = 0
      ex_conditions.each{|f,v| keyvalues.push("ex_cond#{counter}=#{counter}&ex_field#{counter}=#{f}&ex_value#{counter}=#{v}"); counter += 1}
      csv_url = '/ybz/search.csv?andor=' + andor + '&ex_andor=' + ex_andor + '&' + keyvalues.join('&')
      @copypastable = true
      haml :detailsearch, :locals => {
        :andor => andor, :conditions => conditions,
        :ex_andor => ex_andor, :ex_conditions => ex_conditions,
        :csv_url => csv_url
      }
    end
  end

  ### 一覧系 ###

  # サービス一覧 ( /ybz/service/list が別途後ろの方に作成してあるので注意。現状中身はいっしょ。)
  get '/ybz/services' do
    authorized?
    @services = Yabitz::Model::Service.all.sort
    Stratum.preload(@services, Yabitz::Model::Service)
    @page_title = "サービス"
    haml :services
  end

  get %r!/ybz/service/diff/(\d+)! do |oid|
    authorized?
    @service = Yabitz::Model::Service.get(oid.to_i)
    pass unless @service

    @host_record_pairs = nil
    startdate = request.params['from']
    enddate = request.params['to']
    unless startdate and startdate =~ %r!\A\d{4}[-/]?\d{2}[-/]?\d{2}\Z! and enddate and enddate =~ %r!\A\d{4}[-/]?\d{2}[-/]?\d{2}\Z!
      @hide_selectionbox = true
      return haml :service_diff
    end

    startdate =~ %r!\A(\d{4})[-/]?(\d{2})[-/]?(\d{2})\Z!
    startdate = $1 + '-' + $2 + '-' + $3
    enddate =~ %r!\A(\d{4})[-/]?(\d{2})[-/]?(\d{2})\Z!
    enddate = $1 + '-' + $2 + '-' + $3

    @first_timestamp = startdate + ' 00:00:00'
    @last_timestamp = enddate + ' 23:59:59'


    pre_oids = Yabitz::Model::Host.query(:service => @service, :before => @first_timestamp, :oidonly => true)
    post_oids = Yabitz::Model::Host.query(:service => @service, :before => @last_timestamp, :oidonly => true)
    oids = (pre_oids + post_oids).uniq

    pre_hosts_hash = Hash[*(Yabitz::Model::Host.get(oids, :before => @first_timestamp, :force_all => true).map{|h| [h.oid, h]}.flatten)]
    post_hosts_hash = Hash[*(Yabitz::Model::Host.get(oids, :before => @last_timestamp, :force_all => true).map{|h| [h.oid, h]}.flatten)]
    pre_hosts = oids.map{|i| pre_hosts_hash[i]}
    post_hosts = oids.map{|i| post_hosts_hash[i]}

    @host_record_pairs = [post_hosts, pre_hosts].transpose.select{|a,b| (not a and b) or (a and not b) or (a and b and a.id != b.id)}
    @hide_selectionbox = true
    haml :service_diff
  end

  # サービスに対するホスト一覧
  get %r!/ybz/hosts/service/(\d+)(\.json|\.csv)?! do |oid, ctype|
    authorized?
    @srv = Yabitz::Model::Service.get(oid.to_i)
    pass unless @srv # object not found -> HTTP 404

    @hosts = Yabitz::Model::Host.query(:service => @srv).select{|h| h.status != Yabitz::Model::Host::STATUS_REMOVED}
    Stratum.preload(@hosts, Yabitz::Model::Host)
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @hosts.to_json
    when '.csv'
      response['Content-Type'] = 'text/csv'
      Yabitz::Model::Host.build_raw_csv(Yabitz::Model::Host::CSVFIELDS_LL, @hosts)
    else
      #TODO sort order options
      @hosts.sort!
      @page_title = "ホスト一覧 (サービス: #{@srv.name})"
      @copypastable = true
      haml :hosts, :locals => {:cond => "サービス: #{@srv.name}, コンテンツ: #{@srv.content.name}"}
    end
  end

  # IPアドレスからのホスト一覧
  get %r!/ybz/hosts/ipaddress/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(\.json|\.csv)?! do |address, ctype|
    authorized?
    ip = Yabitz::Model::IPAddress.query(:address => address, :unique => true)
    pass unless ip and ip.hosts.size > 0

    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      ip.hosts.to_json
    when '.csv'
      response['Content-Type'] = 'text/csv'
      Yabitz::Model::Host.build_raw_csv(Yabitz::Model::Host::CSVFIELDS_LL, ip.hosts)
    else
      @hosts = ip.hosts
      @hosts.sort!
      @page_title = "ホスト一覧 (IPアドレス: #{address})"
      @copypastable = true
      haml :hosts, :locals => {:cond => "IPアドレス: #{address}"}
    end
  end

  # 特定のステータスのホスト一覧 (removed/missing/other などでの参照を想定)
  get %r!/ybz/hosts/status/([_a-z]+)(\.json|\.csv)?! do |status, ctype|
    authorized?
    pass unless Yabitz::Model::Host::STATUS_LIST.include?(status.upcase)

    @hosts = Yabitz::Model::Host.query(:status => status.upcase)
    Stratum.preload(@hosts, Yabitz::Model::Host)
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @hosts.to_json
    when '.csv'
      response['Content-Type'] = 'text/csv'
      Yabitz::Model::Host.build_raw_csv(Yabitz::Model::Host::CSVFIELDS_LL, @hosts)
    else
      @hosts.sort!
      status_title = Yabitz::Model::Host.status_title(status.upcase)
      @page_title = "ホスト一覧 (状態: #{status_title})"
      @copypastable = true
      haml :hosts, :locals => {:cond => "状態: #{status_title}"}
    end
  end

  get %r!/ybz/hosts/all(\.json|\.csv)! do |ctype|
    authorized?
    started = Time.now
    @hosts = Yabitz::Model::Host.all
    preloading = Time.now
    Stratum.preload(@hosts, Yabitz::Model::Host)
    loaded = Time.now
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @hosts.to_json
    when '.csv'
      response['Content-Type'] = 'text/csv'
      response['X-DATA-STARTED'] = started.to_s
      response['X-DATA_PRELOAD'] = preloading.to_s
      response['X-DATA-LOADED'] = loaded.to_s
      # Yabitz::Model::Host.build_raw_csv(Yabitz::Model::Host::CSVFIELDS_LL, @hosts)
      str = Yabitz::Model::Host.build_raw_csv_burst_llfields(@hosts)
      response['X-DATA-RESPONSE'] = Time.now.to_s
      str
    else
      pass
    end
  end

  ### ホスト操作 ###

  # ホスト作成
  get '/ybz/host/create' do
    admin_protected!
    target_service = if params[:service]
                       Yabitz::Model::Service.get(params[:service].to_i)
                     else
                       nil
                     end
    @page_title = 'ホスト追加'
    haml :host_create, :locals => {:cond => @page_title, :target => target_service}
  end

  post '/ybz/host/create' do
    admin_protected!
    params = request.params

    service = Yabitz::Model::Service.get(params['service'].to_i)
    raise Yabitz::InconsistentDataError, "所属サービスが指定されていません" unless service
    unless params['status'] and Yabitz::Model::Host::STATUS_LIST.include?(params['status'])
      raise Yabitz::InconsistentDataError, "作成後の状態が指定されていません"
    end

    opetag = Yabitz::OpeTagGenerator.generate

    Stratum.transaction do |conn|
      hv_list = []
      hook_insert_host_list = []

      params.keys.select{|k| k =~ /\Aadding\d+\Z/}.each do |key|
        i = params[key].to_i.to_s

        # host-creation only validation (insufficiant case with Yabitz::Model::Host validators)
        hosttype = Yabitz::HostType.new(params["type#{i}"])
        if hosttype.host?
          raise Yabitz::InconsistentDataError, "ホスト作成時には必ずメモリ容量を入力してください" if not params["memory#{i}"] or params["memory#{i}"].strip.empty?
          raise Yabitz::InconsistentDataError, "ホスト作成時には必ずHDD容量を入力してください" if not params["disk#{i}"] or params["disk#{i}"].strip.empty?
        end

        host = Yabitz::Model::Host.new
        host.service = service
        host.status = params['status']
        host.type = hosttype.name
        host.rackunit = params["rackunit#{i}"].strip.empty? ? nil : Yabitz::Model::RackUnit.query_or_create(:rackunit => params["rackunit#{i}"].strip)
        host.hwid = params["hwid#{i}"].strip
        host.hwinfo = params["hwinfo#{i}"].strip.empty? ? nil : Yabitz::Model::HwInformation.get(params["hwinfo#{i}"].to_i)
        host.memory = params["memory#{i}"].strip
        host.disk = params["disk#{i}"].strip
        host.os = params["os#{i}"].strip.empty? ? "" : Yabitz::Model::OSInformation.get(params["os#{i}"].to_i).name
        host.dnsnames = params["dnsnames#{i}"].split(/\s+/).select{|n|n.size > 0}.map{|dns| Yabitz::Model::DNSName.query_or_create(:dnsname => dns)}
        host.localips = params["localips#{i}"].split(/\s+/).select{|n|n.size > 0}.map{|lip| Yabitz::Model::IPAddress.query_or_create(:address => lip)}
        host.globalips = params["globalips#{i}"].split(/\s+/).select{|n|n.size > 0}.map{|gip| Yabitz::Model::IPAddress.query_or_create(:address => gip)}
        host.virtualips = params["virtualips#{i}"].split(/\s+/).select{|n|n.size > 0}.map{|gip| Yabitz::Model::IPAddress.query_or_create(:address => gip)}

        if host.hwid and host.hwid.length > 0 and not hosttype.virtualmachine?
          bricks = Yabitz::Model::Brick.query(:hwid => host.hwid)
          unless bricks.first.nil? or bricks.first.status == Yabitz::Model::Brick::STATUS_STOCK
            raise Yabitz::InconsistentDataError, "指定されたhwid #{host.hwid} に対応する機器が「#{Yabitz::Model::Brick.status_title(Yabitz::Model::Brick::STATUS_STOCK)}」以外の状態です"
          end
          if bricks.size == 1
            brick = bricks.first
            brick.status = Yabitz::Model::Brick::STATUS_IN_USE
            brick.heap = host.rackunit.rackunit if host.rackunit
            if service.content and service.content.code and service.content.code.length > 0 and service.content.code != 'NONE'
              brick.served!
            end
            brick.save
          end
        end

        tags = Yabitz::Model::TagChain.new
        tags.tagchain = ([opetag] + params["tagchain#{i}"].strip.split(/\s+/)).flatten.compact
        host.tagchain = tags

        # host.parent / host.children
        if host.hosttype.virtualmachine? and host.rackunit and host.hwid and not host.hwid.empty?
          hv_oids = Yabitz::Model::Host.query(:rackunit => host.rackunit, :hwid => host.hwid, :type => host.hosttype.hypervisor.name, :oidonly => true)
          raise Yabitz::InconsistentDataError, "ラック位置とHWIDが同一のハイパーバイザが2台以上存在します" if hv_oids.size > 1
          raise Yabitz::InconsistentDataError, "ゲスト指定されていますがラック位置とHWIDの一致するハイパーバイザがありません" if hv_oids.size < 1

          unless hv_list.map(&:oid).include?(hv_oids.first)
            hv_list.push(Yabitz::Model::Host.get(hv_oids.first))
          end
          hv = hv_list.select{|h| h.oid == hv_oids.first}.first

          if hv.saved?
            hv.prepare_to_update()
            unless hv.tagchain.tagchain.include?(opetag)
              hv.tagchain.tagchain += [opetag]
              hv.tagchain.save
            end
          end
          host.parent = hv
          unless hv.dnsnames.map(&:dnsname).include?('p.' + host.dnsnames.first.dnsname)
            hv.dnsnames += [Yabitz::Model::DNSName.query_or_create(:dnsname => 'p.' + host.dnsnames.first.dnsname)]
          end
        end

        host.save
        tags.save

        hook_insert_host_list.push(host)
      end

      Yabitz::Plugin.get(:handler_hook).each do |plugin|
        if plugin.respond_to?(:host_insert)
          hook_insert_host_list.each do |h|
            plugin.host_insert(h)
          end
        end
      end

      hv_list.each do |hv|
        # for handler_hook, un-cached object get
        pre_state = Yabitz::Model::Host.get(hv.oid, :ignore_cache => true)

        hv.save

        Yabitz::Plugin.get(:handler_hook).each do |plugin|
          if plugin.respond_to?(:host_update)
            plugin.host_update(pre_state, hv)
          end
        end
      end
    end

    "opetag:" + opetag
  end

  # JSON PUT API は生データを投入するイメージ
  # brick連動はなし
  put '/ybz/host/create' do
    admin_protected!
    json = JSON.load(request.body)

    service = Yabitz::Model::Service.query(:name => json['service'], :unique => true);
    raise Yabitz::InconsistentDataError, "所属サービスが指定されていません" unless service
    unless json['status'] and Yabitz::Model::Host::STATUS_LIST.include?(json['status'])
      raise Yabitz::InconsistentDataError, "作成後の状態が指定されていません"
    end

    Stratum.transaction do |conn|
      hv_list = []

      params.keys.select{|k| k =~ /\Aadding\d+\Z/}.each do |key|
        i = params[key].to_i.to_s

        # host-creation only validation (insufficiant case with Yabitz::Model::Host validators)
        hosttype = Yabitz::HostType.new(json["type"])
        if hosttype.host?
          raise Yabitz::InconsistentDataError, "ホスト作成時には必ずメモリ容量を入力してください" if not json["memory"] or json["memory"].empty?
          raise Yabitz::InconsistentDataError, "ホスト作成時には必ずHDD容量を入力してください" if not json["disk"] or json["disk"].empty?
        end

        host = Yabitz::Model::Host.new
        host.service = service
        host.status = json['status']
        host.type = hosttype.name
        host.rackunit = (json["rackunit"].nil? or json["rackunit"].empty?) ? nil : Yabitz::Model::RackUnit.query_or_create(:rackunit => json["rackunit"])
        host.hwid = json["hwid"]
        host.hwinfo = (json["hwinfo"].nil? or json['hwinfo'].empty?) ? nil : Yabitz::Model::HwInformation.query(:name => json["hwinfo"], :unique => true)
        host.memory = json["memory"]
        host.disk = json["disk"]
        host.os = json['os']
        host.dnsnames = json["dnsnames"].map{|dns| Yabitz::Model::DNSName.query_or_create(:dnsname => dns)}
        host.localips = json["localips"].map{|lip| Yabitz::Model::IPAddress.query_or_create(:address => lip)}
        host.globalips = json["globalips"].map{|gip| Yabitz::Model::IPAddress.query_or_create(:address => gip)}
        host.virtualips = json["virtualips"].map{|gip| Yabitz::Model::IPAddress.query_or_create(:address => gip)}

        # host.parent / host.children
        if host.hosttype.virtualmachine? and host.rackunit and host.hwid and not host.hwid.empty?
          hv_oids = Yabitz::Model::Host.query(
                                              :rackunit => host.rackunit, :hwid => host.hwid,
                                              :type => host.hosttype.hypervisor.name, :oidonly => true)
          raise Yabitz::InconsistentDataError, "ラック位置とHWIDが同一のハイパーバイザが2台以上存在します" if hv_oids.size > 1
          raise Yabitz::InconsistentDataError, "ゲスト指定されていますがラック位置とHWIDの一致するハイパーバイザがありません" if hv_oids.size < 1

          unless hv_list.map(&:oid).include?(hv_oids.first)
            hv_list.push(Yabitz::Model::Host.get(hv_oids.first))
          end
          hv = hv_list.select{|h| h.oid == hv_oids.first}.first

          if hv.saved?
            hv.prepare_to_update()
          end
          host.parent = hv
          unless hv.dnsnames.map(&:dnsname).include?('p.' + host.dnsnames.first.dnsname)
            hv.dnsnames += [Yabitz::Model::DNSName.query_or_create(:dnsname => 'p.' + host.dnsnames.first.dnsname)]
          end
        end

        host.save
      end

      hv_list.each do |hv|
        hv.save
      end
    end
    'ok'
  end


  # ホスト変更履歴
  get '/ybz/host/history/:oidlist' do |oidlist|
    authorized?
    @host_records = []
    oidlist.split('-').map(&:to_i).each do |oid|
      @host_records += Yabitz::Model::Host.retrospect(oid)
    end
    @host_records.sort!{|a,b| ((b.inserted_at.to_i <=> a.inserted_at.to_i) != 0) ? (b.inserted_at.to_i <=> a.inserted_at.to_i) : (b.id.to_i <=> a.id.to_i)}
    @oidlist = oidlist
    @hide_detailview = true
    haml :host_history
  end

  get %r!/ybz/host/diff/([-0-9]+)/(\d+)/?(\d+)?! do |oidlist, endpoint, startpoint|
    authorized?
    @id_end = endpoint.to_i
    @id_start = startpoint.to_i # if nil, id_start == 0
    @first_timestamp = nil
    @last_timestamp = nil
    @host_record_pairs = []
    oidlist.split('-').map(&:to_i).each do |oid|
      records = Yabitz::Model::Host.retrospect(oid)
      next if records.size < 1
      after = records.select{|h| h.id <= @id_end}.sort{|a,b| b.id <=> a.id}.first
      before = records.select{|h| h.id <= @id_start}.sort{|a,b| b.id <=> a.id}.first

      if (@first_timestamp.nil? and before) or (before and @first_timestamp.to_i > before.inserted_at.to_i)
        @first_timestamp = before.inserted_at
      end
      if (@last_timestamp.nil? and after) or (after and @last_timestamp.to_i < after.inserted_at.to_i)
        @last_timestamp = after.inserted_at
      end

      @host_record_pairs.push([after, before])
    end

    @hide_selectionbox = true
    haml :host_diff
  end

  get %r!/ybz/operations/?(\d{8})?/?(\d{8})?! do |start_date, end_date|
    authorized?
    @start_date = start_date
    @end_date = end_date
    # array of [date, tags]
    @tags_collection = if start_date and end_date
                         Yabitz::Model::TagChain.opetags_range(start_date, end_date)
                       else
                         Yabitz::Model::TagChain.active_opetags
                       end
    @hide_selectionbox = true
    haml :opetag_list
  end

  get %r!/ybz/host/operation/([^.]+)(\.ajax)?! do |ope, ctype|
    authorized?
    @opetag = ope

    case ctype
    when '.ajax'
      @hosts = Yabitz::Model::Host.get(Yabitz::Model::TagChain.query(:tagchain => @opetag).map(&:host_by_id), :force_all => true)
      haml :opetag_parts, :layout => false
    else
      tags = Yabitz::Model::TagChain.query(:tagchain => @opetag, :select => :first)
      @host_record_pairs = []
      tags.each do |tag|
        records = Yabitz::Model::Host.retrospect(tag.host_by_id)
        next if records.size < 1
        
        # '15' is magic number, but maybe operations (with opetag) is once in 30 seconds
        after = records.select{|h| (tag.inserted_at - 15) <= h.inserted_at and h.inserted_at <= (tag.inserted_at + 15)}.first
        before = records.select{|h| h.inserted_at < (tag.inserted_at - 15)}.first

        @host_record_pairs.push([after, before])
      end
      @hide_selectionbox = true
      haml :opetag_diff
    end
  end

  # ホスト詳細表示
  get %r!/ybz/host/([-0-9]+)(\.json|\.ajax|\.tr\.ajax|(\.[SML])?\.csv)?! do |oidlist, ctype, size|
    authorized?
    @hosts = Yabitz::Model::Host.get(oidlist.split('-').map(&:to_i))
    pass if @hosts.empty? # object not found -> HTTP 404

    Stratum.preload(@hosts, Yabitz::Model::Host);
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @hosts.to_json
    when '.ajax'
      raise RuntimeError, "ajax host detail call accepts only 1 host" if @hosts.size > 1
      @host = @hosts.first
      haml :host_parts, :layout => false
    when '.tr.ajax'
      raise RuntimeError, "ajax host detail call accepts only 1 host" if @hosts.size > 1
      @host = @hosts.first
      haml :host, :layout => false, :locals => {:host => @host}
    when '.S.csv', '.M.csv', '.L.csv'
      response['Content-Type'] = 'text/csv'
      fields = case ctype
               when '.S.csv' then Yabitz::Model::Host::CSVFIELDS_S
               when '.M.csv' then Yabitz::Model::Host::CSVFIELDS_M
               when '.L.csv' then Yabitz::Model::Host::CSVFIELDS_L
               end
      Yabitz::Model::Host.build_csv(fields, @hosts)
    when '.csv'
      response['Content-Type'] = 'text/csv'
      Yabitz::Model::Host.build_raw_csv(Yabitz::Model::Host::CSVFIELDS_LL, @hosts)
    else
      @page_title = "ホスト: #{@hosts.map(&:display_name).join(', ')}"
      @copypastable = true
      @default_selected_all = true
      haml :hosts, :locals => {:cond => @page_title}
    end
  end

  # ホスト情報変更
  post %r!/ybz/host/(\d+)! do |oid|
    protected!

    Stratum.transaction do |conn|
      @host = Yabitz::Model::Host.get(oid.to_i)

      # for update hook
      pre_host_status = Yabitz::Model::Host.get(oid.to_i, :ignore_cache => true)

      pass unless @host
      if request.params['target_id']
        unless request.params['target_id'].to_i == @host.id
          raise Stratum::ConcurrentUpdateError
        end
      end

      field = request.params['field'].to_sym
      unless @isadmin or field == :notes or field == :tagchain
        halt HTTP_STATUS_FORBIDDEN, "not authorized"
      end

      @host.send(field.to_s + '=', @host.map_value(field, request))
      @host.save

      Yabitz::Plugin.get(:handler_hook).each do |plugin|
        if plugin.respond_to?(:host_update)
          plugin.host_update(pre_host_status, @host)
        end
      end
    end
    
    "ok"
  end

  # JSON PUT API は生データを直接書き換えるイメージなので、連動して他のステータスが変わるようなフックは実行しない
  # ということにする
  put %r!/ybz/host/(\d+)! do |oid|
    admin_protected!
    json = JSON.load(request.body)
    halt HTTP_STATUS_NOT_ACCEPTABLE, "mismatch oid between request #{json['oid']} and URI #{oid}" unless oid.to_i == json['oid'].to_i

    Stratum.transaction do |conn|
      host = Yabitz::Model::Host.get(oid.to_i)
      halt HTTP_STATUS_CONFLICT unless host.id == json['id'].to_i

      # for update hook
      pre_host_status = Yabitz::Model::Host.get(oid.to_i, :ignore_cache => true)
      pre_children_status = Yabitz::Model::Host.get(pre_host_status.children_by_id, :ignore_cache => true)

      content = json['content']

      host.service = Yabitz::Model::Service.get(content['service'].to_i) unless equal_in_fact(host.service_by_id, content['service'])
      host.status = content['status'] unless equal_in_fact(host.status, content['status'])
      host.type = Yabitz::HostType.new(content['type']).name unless equal_in_fact(host.type, content['type'])
      unless equal_in_fact(host.rackunit, content['rackunit'])
        host.rackunit = if content['rackunit'].nil? or content['rackunit'].empty?
                          nil
                        else
                          Yabitz::Model::RackUnit.query_or_create(:rackunit => content['rackunit'])
                        end
        if host.hosttype.hypervisor?
          host.children.each do |c|
            c.rackunit = host.rackunit
          end
        end
      end
      unless equal_in_fact(host.hwid, content['hwid'])
        host.hwid = content['hwid']
        if host.hosttype.hypervisor?
          host.children.each do |c|
            c.hwid = content['hwid']
          end
        end
      end

      unless equal_in_fact(host.hwinfo, content['hwinfo'])
        host.hwinfo = if content['hwinfo'].nil? or content['hwinfo'].empty?
                        nil
                      else
                        Yabitz::Model::HwInformation.query_or_create(:name => content['hwinfo'])
                      end
      end
      host.memory = content['memory'] unless equal_in_fact(host.memory, content['memory'])
      host.disk = content['disk'] unless equal_in_fact(host.disk, content['disk'])
      unless equal_in_fact(host.os, content['os'])
        host.os = if content['os'].nil? or content['os'].empty?
                    nil
                  else
                    Yabitz::Model::OSInformation.query_or_create(:name => content['os']).name
                  end
      end
      unless equal_in_fact(host.dnsnames, content['dnsnames'])
        if content['dnsnames']
          host.dnsnames = content['dnsnames'].map{|dns| Yabitz::Model::DNSName.query_or_create(:dnsname => dns)}
        else
          host.dnsnames = []
        end
      end
      unless equal_in_fact(host.localips, content['localips'])
        if content['localips']
          host.localips = content['localips'].map{|lip| Yabitz::Model::IPAddress.query_or_create(:address => lip)}
        else
          host.localips = []
        end
      end
      unless equal_in_fact(host.globalips, content['globalips'])
        if content['globalips']
          host.globalips = content['globalips'].map{|lip| Yabitz::Model::IPAddress.query_or_create(:address => lip)}
        else
          host.globalips = []
        end
      end
      unless equal_in_fact(host.virtualips, content['virtualips'])
        if content['virtualips']
          host.virtualips = content['virtualips'].map{|lip| Yabitz::Model::IPAddress.query_or_create(:address => lip)}
        else
          host.virtualips = []
        end
      end
      tags = content['tagchain'].is_a?(Array) ? content['tagchain'] : (content['tagchain'] && content['tagchain'].split(/\s+/))
      unless equal_in_fact(host.tagchain.tagchain, tags)
        host.tagchain.tagchain = tags
        host.tagchain.save
      end
      host.notes = content['notes'] unless equal_in_fact(host.notes, content['notes'])
      if not host.saved?
        host.save
        host.children.each do |child|
          child.save unless child.saved?
        end
      end

      Yabitz::Plugin.get(:handler_hook).each do |plugin|
        if plugin.respond_to?(:host_update)
          plugin.host_update(pre_host_status, host)
          [pre_children_status, host.children].transpose.each do |pre, post|
            plugin.host_update(pre, post)
          end
        end
      end
    end
    "ok"
  end

  # 複数ホスト一括変更 (status_* / change_service / add_tag / tie_hypervisor / change_dns / delete_records)
  post '/ybz/host/alter-prepare/:ope/:oidlist' do
    admin_protected!
    oidlist = params[:oidlist].split('-').map(&:to_i)
    hosts = Yabitz::Model::Host.get(oidlist)
    unless oidlist.size == hosts.size
      halt HTTP_STATUS_CONFLICT, "指定されたホストの全部もしくは一部が見付かりません<br />ページを更新してやりなおしてください"
    end
    
    case params[:ope]
    when 'status_under_dev', 'status_in_service', 'status_no_count', 'status_suspended', 'status_standby',
      'status_removing', 'status_removed', 'status_missing', 'status_other'
      st_title = Yabitz::Model::Host.status_title(params[:ope] =~ /\Astatus_(.+)\Z/ ? $1.upcase : nil)
      "状態: #{st_title} へ変更していいですか？"
    when 'change_service'
      Stratum.preload(Yabitz::Model::Service.all, Yabitz::Model::Service)
      service_select_tag_template = <<EOT
%div 変更先サービスを選択してください
%div
  %select{:name => "service"}
    - Yabitz::Model::Service.all.sort.each do |service|
      %option{:value => service.oid}&= service.name + ' [' + service.content.to_s + ']'
EOT
      haml service_select_tag_template, :layout => false
    when 'add_tag'
      tag_input_template = <<EOT
%div 付与するタグを入力してください
%div
  %input{:type => "text", :name => "tag", :size => 16}
EOT
      haml tag_input_template, :layout => false
    when 'delete_records'
      "選択されたホストすべてのデータを削除して本当にいいですか？<br />" + hosts.map{|host| h(host.display_name)}.join('<br />')
    when 'tie_hypervisor'
      if hosts.select{|h| t = h.hosttype; (not t.hypervisor?) and (not t.virtualmachine?)}.size > 0
        halt HTTP_STATUS_NOT_ACCEPTABLE, "ハイパーバイザおよびゲスト以外のホストが選択に含まれています"
      end

      hv_host = hosts.select{|h| h.hosttype.hypervisor?}
      unless hv_host.size == 1
        halt HTTP_STATUS_NOT_ACCEPTABLE, "ハイパーバイザのホストをひとつだけ指定してください"
      end
      hv_host = hv_host.first

      guest_hosts = hosts.select{|h| h.hosttype.virtualmachine?}
      unless guest_hosts.inject(true){|t,h| t and h.hosttype.hypervisor.name == hv_host.hosttype.name}
        halt HTTP_STATUS_NOT_ACCEPTABLE, "ハイパーバイザとゲストの間で種類が合っていないものが含まれています"
      end

      unless guest_hosts.inject(true){|t,h| t and (h.hwid.nil? or h.hwid.empty? or h.hwid == hv_host.hwid) and (h.rackunit.nil? or h.rackunit_by_id == hv_host.rackunit_by_id)}
        halt HTTP_STATUS_OK, "HWIDおよびラック位置の異なるものが含まれていますが、親 #{hv_host.display_name} 子 #{guest_hosts.map(&:display_name).join(',')} の関係を設定を強行しますか？"
      end

      "親 #{hv_host.display_name} 子 #{guest_hosts.map(&:display_name).join(',')} の関係を設定していいですか？"
    when 'change_dns'
      if hosts.select{|host| host.dnsnames.nil? or host.dnsnames.empty? or host.dnsnames.size > 1}.size > 0
        halt HTTP_STATUS_NOT_ACCEPTABLE, "指定されたホストに、以下のものが含まれています<br />dns名を持っていない、あるいは複数のdns名を持っている<br />この対象はdns名の一斉変更ができません"
      end
      name_parts = hosts.map do |h|
        rev = h.dnsnames.first.dnsname.split('.').reverse
        rev.shift if rev.first == h.hwinfo.to_s
        rev
      end.transpose
      match_parts = []
      name_parts.each do |array|
        if array.inject(){|a,b| (a and a == b) ? a : nil}
          match_parts.push(array.first)
        else
          break
        end
      end
      change_dns_template = if match_parts.size == 0
                              <<EOT
%div dns名の末尾に追加します
%div
  %input{:type => "text", :name => "dns_replace_to", :size => 16}
  %input{:type => "hidden", :name => "dns_replace_from", :value => ""}
EOT
                            else
                              replace_string = match_parts.reverse.join('.')
                              <<EOT
%div dns名の #{h(replace_string)} の部分を置き換えます
%div
  %input{:type => "text", :name => "dns_replace_to", :size => 16}
  %input{:type => "hidden", :name => "dns_replace_from", :value => h(replace_string)}
EOT
                            end
      haml change_dns_template, :layout => false, :locals => {:replace_string => replace_string}
    else
      pass
    end
  end
  
  post '/ybz/host/alter-execute/:ope/:oidlist' do
    admin_protected!
    oidlist = params[:oidlist].split('-').map(&:to_i)
    hosts = Yabitz::Model::Host.get(oidlist)

    # for update hook
    pre_host_status_list = Yabitz::Model::Host.get(oidlist, :ignore_cache => true)

    unless oidlist.size == hosts.size
      halt HTTP_STATUS_CONFLICT, "指定されたホストの全部もしくは一部が見付かりません<br />ページを更新してやりなおしてください"
    end

    case params[:ope]
    when 'status_under_dev', 'status_in_service', 'status_no_count', 'status_suspended', 'status_standby',
      'status_removing', 'status_removed', 'status_missing', 'status_other'
      raise ArgumentError, params[:ope] unless params[:ope] =~ /\Astatus_(.+)\Z/ and Yabitz::Model::Host::STATUS_LIST.include?($1.upcase)
      new_status = $1.upcase
      tag = Yabitz::OpeTagGenerator.generate

      # for udpate hook for hypervisors
      pre_hv_hosts = []
      hv_hosts = []

      Stratum.transaction do |conn|
        hosts.each do |host|
          host.prepare_to_update()

          if host.tagchain.nil?
            host.tagchain = Yabitz::Model::TagChain.new.save
          end
          host.status = new_status

          # if content.code is valid and status is in_service, then brick will be served.
          if host.hwid and host.hwid.length > 0 and not host.hosttype.virtualmachine? and
              new_status == Yabitz::Model::Host::STATUS_IN_SERVICE and host.service and host.service.content and
              host.service.content.code and host.service.content.code.length > 0 and host.service.content.code != 'NONE'
            bricks = Yabitz::Model::Brick.query(:hwid => host.hwid)
            if bricks.size == 1
              brick = bricks.first
              if brick.status == Yabitz::Model::Brick::STATUS_IN_USE
                brick.served!
                brick.save
              end
            end
          end

          if new_status == Yabitz::Model::Host::STATUS_REMOVED
            host.localips = []
            host.globalips = []
            host.virtualips = []

            if host.parent_by_id
              # for update hook
              unless pre_hv_hosts.map(&:oid).include?(host.parent_by_id)
                pre_hv_hosts.push(Yabitz::Model::Host.get(host.parent_by_id, :ignore_cache => true))
                hv_hosts.push(Yabitz::Model::Host.get(host.parent_by_id))
              end

              ph = hv_hosts.select{|hv| hv.oid == host.parent_by_id}.first
              ph.prepare_to_update() if ph.saved?

              unless ph.tagchain.tagchain.include?(tag)
                ph.tagchain.tagchain += [tag]
              end
              ph.dnsnames = ph.dnsnames.select{|d| d.dnsname != 'p.' + host.dnsnames.first.dnsname}
              host.parent = nil
            end
          end
          host.tagchain.tagchain += [tag]
          host.tagchain.save
          host.save
        end
        hv_hosts.each do |hv|
          hv.tagchain.save
          hv.save
        end

        Yabitz::Plugin.get(:handler_hook).each do |plugin|
          if params[:ope] == 'status_removed'
            if plugin.respond_to?(:host_delete)
              hosts.each do |host|
                plugin.host_delete(host)
              end
            end
            if plugin.respond_to?(:host_update)
              if pre_hv_hosts.size > 0
                [pre_hv_hosts, hv_hosts].transpose.each do |pre, post|
                  plugin.host_update(pre, post)
                end
              end
            end
          else
            if plugin.respond_to?(:host_update)
              [pre_host_status_list, hosts].transpose.each do |pre, post|
                plugin.host_update(pre, post)
              end
            end
          end
        end
      end
      "opetag:" + tag
    when 'change_service'
      service = Yabitz::Model::Service.get(params[:service].to_i)
      tag = Yabitz::OpeTagGenerator.generate
      Stratum.transaction do |conn|
        hosts.each do |host|
          if host.tagchain.nil?
            host.tagchain = Yabitz::Model::TagChain.new.save
          end

          host.service = service

          # if content.code is valid and status is in_service, then brick will be served.
          if host.hwid and host.hwid.length > 0 and not host.hosttype.virtualmachine? and
              host.status == Yabitz::Model::Host::STATUS_IN_SERVICE and service and service.content and
              service.content.code and service.content.code.length > 0 and service.content.code != 'NONE'
            bricks = Yabitz::Model::Brick.query(:hwid => host.hwid)
            if bricks.size == 1
              brick = bricks.first
              if brick.status == Yabitz::Model::Brick::STATUS_IN_USE
                brick.served!
                brick.save
              end
            end
          end

          host.tagchain.tagchain += [tag]
          host.tagchain.save
          host.save
        end

        Yabitz::Plugin.get(:handler_hook).each do |plugin|
          if plugin.respond_to?(:host_update)
            [pre_host_status_list, hosts].transpose.each do |pre, post|
              plugin.host_update(pre, post)
            end
          end
        end
      end
      "opetag:" + tag
    when 'add_tag'
      tag = params[:tag]
      Stratum.transaction do |conn|
        hosts.each do |host|
          if host.tagchain.nil?
            host.tagchain = Yabitz::Model::TagChain.new.save
          end
          host.tagchain.tagchain += [tag]
          host.tagchain.save
          host.save
        end
        
        Yabitz::Plugin.get(:handler_hook).each do |plugin|
          if plugin.respond_to?(:host_update)
            [pre_host_status_list, hosts].transpose.each do |pre, post|
              plugin.host_update(pre, post)
            end
          end
        end
      end
      tag
    when 'delete_records'
      tag = Yabitz::OpeTagGenerator.generate
      Stratum.transaction do |conn|
        hosts.each do |host|
          if host.tagchain.nil?
            host.tagchain = Yabitz::Model::TagChain.new.save
          end
          host.parent = nil
          host.children = []
          host.rackunit = nil
          host.hwinfo = nil
          host.dnsnames = []
          host.localips = []
          host.globalips = []
          host.virtualips = []
          host.tagchain.tagchain += [tag]
          host.tagchain.save
          host.save

          host.remove
        end

        Yabitz::Plugin.get(:handler_hook).each do |plugin|
          if plugin.respond_to?(:host_delete)
            pre_host_status_list.each do |host|
              plugin.host_delete(host)
            end
          end
        end
      end
      "opetag:" + tag
    when 'tie_hypervisor'
      tag = Yabitz::OpeTagGenerator.generate

      Stratum.transaction do |conn|
        hv_host = hosts.select{|h| h.hosttype.hypervisor?}.first
        guest_hosts = hosts.select{|h| h.hosttype.virtualmachine?}
        raise Yabitz::InconsistentDataError, "ホスト選択が不整合" unless guest_hosts.size + 1 == hosts.size
        unless guest_hosts.inject(true){|t,h| t and h.hosttype.hypervisor.name == hv_host.hosttype.name}
          raise Yabitz::InconsistentDataError, "ハイパーバイザとゲストの間で種類が不整合"
        end
        
        hv_host.prepare_to_update()

        guest_hosts.each do |g|
          g.hwid = hv_host.hwid if g.hwid.nil? or g.hwid.empty?
          g.rackunit = hv_host.rackunit unless g.rackunit
          g.parent = hv_host
          g.tagchain.tagchain += [tag]
          g.tagchain.save
          g.save

          p_dnsname = Yabitz::Model::DNSName.query_or_create(:dnsname => 'p.' + g.dnsnames.first.dnsname)
          unless hv_host.dnsnames.map(&:oid).include?(p_dnsname.oid)
            hv_host.dnsnames += [p_dnsname]
          end
          p_dnsname.hosts.select{|h| h.hosttype.hypervisor? and not h.children_by_id.include?(g.oid)}.each do |pre_hv|
            pre_hv.dnsnames = pre_hv.dnsnames.select{|dns| dns.oid != p_dnsname.oid}
            pre_hv.tagchain.tagchain += [tag]
            pre_hv.tagchain.save
            pre_hv.save
          end
        end
        hv_host.tagchain.tagchain += [tag]
        hv_host.tagchain.save
        hv_host.save

        Yabitz::Plugin.get(:handler_hook).each do |plugin|
          if plugin.respond_to?(:host_update)
            [pre_host_status_list, hosts].transpose.each do |pre, post|
              plugin.host_update(pre, post)
            end
          end
        end
      end
      "opetag:" + tag
    when 'change_dns'
      tag = Yabitz::OpeTagGenerator.generate
      replace_from_part = params[:dns_replace_from]
      replace_to_part = params[:dns_replace_to]
      Stratum.transaction do |conn|
        hosts.each do |host|
          raise Yabitz::InconsistentDataError.new("dns名の数が不正です") unless host.dnsnames.size == 1
          if host.tagchain.nil?
            host.tagchain = Yabitz::Model::TagChain.new.save
          end
          replaced = if replace_from_part.size > 0
                       host.dnsnames.first.dnsname.sub(replace_from_part, replace_to_part)
                     else
                       host.dnsnames.first.dnsname + replace_to_part
                     end
          host.dnsnames = Yabitz::Model::DNSName.query_or_create(:dnsname => replaced)
          host.tagchain.tagchain += [tag]
          host.tagchain.save
          host.save
        end

        Yabitz::Plugin.get(:handler_hook).each do |plugin|
          if plugin.respond_to?(:host_update)
            [pre_host_status_list, hosts].transpose.each do |pre, post|
              plugin.host_update(pre, post)
            end
          end
        end
      end
      "opetag:" + tag
    else
      pass
    end
  end

  ### 管理用 情報閲覧・操作 ###
  
  # hostに対して service,contact,dnsname,ipaddress,rackunit,hwidの欠落および重複をチェックして一覧出力
  get '/ybz/checker' do
    authorized?
    @result = Yabitz::Checker.check
    haml :checker
  end

  get '/ybz/systemchecker' do 
    authorized?
    "ok" #TODO write!
  end

  ### 各リソースの状態表示、および管理(holdなど)
  #TODO serviceurl

  get %r!/ybz/ipsegment/list/(local|global)(\.json)?! do |net, ctype|
    authorized?
    area = (net == 'local' ? Yabitz::Model::IPSegment::AREA_LOCAL : Yabitz::Model::IPSegment::AREA_GLOBAL)
    @ipsegments = Yabitz::Model::IPSegment.query(:area => area)
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @ipsegments.to_json
    else
      @ips = Yabitz::Model::IPAddress.choose(:hosts, :holder, :lowlevel => true){|hosts,holder| (not hosts.nil? and not hosts.empty?) or holder == Stratum::Model::BOOL_TRUE}
      @segment_network_map = {}
      @segment_used_ip_map = {}
      @ipsegments.each do |seg|
        @segment_network_map[seg.to_s] = seg.to_addr
        @segment_used_ip_map[seg.to_s] = []
      end
      @ips.each do |ip|
        @ipsegments.each do |seg|
          if @segment_network_map[seg.to_s].include?(ip.to_addr)
            @segment_used_ip_map[seg.to_s].push(ip)
            break
          end
        end
      end

      @page_title = "IPセグメントリスト(#{net} network)"
      @ipsegments.sort!
      haml :ipsegment_list
    end
  end

  get %r!/ybz/ipsegment/list/network/([:.0-9]+\d/\d+)(\.json)?! do |network_str, ctype|
    authorized?
    network = IPAddr.new(network_str)
    @ipsegments = Yabitz::Model::IPSegment.choose(:address){|v| network.include?(IPAddr.new(v))}
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @ipsegments.to_json
    else
      @ips = Yabitz::Model::IPAddress.choose(:hosts, :holder, :lowlevel => true){|hosts,holder| (not hosts.nil? and not hosts.empty?) or holder == Stratum::Model::BOOL_TRUE}
      @segment_network_map = {}
      @segment_used_ip_map = {}
      @ipsegments.each do |seg|
        @segment_network_map[seg.to_s] = seg.to_addr
        @segment_used_ip_map[seg.to_s] = []
      end
      @ips.each do |ip|
        @ipsegments.each do |seg|
          if @segment_network_map[seg.to_s].include?(IPAddr.new(ip.address))
            @segment_used_ip_map[seg.to_s].push(ip)
            break
          end
        end
      end

      @page_title = "IPセグメント (範囲: #{network_str})"
      @ipsegments.sort!
      haml :ipsegment_list
    end
  end

  get %r!/ybz/ipsegment/(\d+)(\.tr\.ajax|\.ajax|\.json)?! do |oid, ctype|
    authorized?
    @ipseg = Yabitz::Model::IPSegment.get(oid.to_i)
    pass unless @ipseg
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @ipseg.to_json
    when '.tr.ajax'
      network = IPAddr.new(@ipseg.address + '/' + @ipseg.netmask)
      @ips = Yabitz::Model::IPAddress.choose(:hosts, :holder, :address, :lowlevel => true){|hosts,holder,address|
        ((not hosts.nil? and not hosts.empty?) or holder == Stratum::Model::BOOL_TRUE) and network.include?(IPAddr.new(address))
      }
      @segment_used_ip_map = {@ipseg.to_s => @ips}
      haml :ipsegment, :layout => false, :locals => {:ipsegment => @ipseg}
    when '.ajax'
      haml :ipsegment_parts, :layout => false
    else
      @network = @ipseg.to_addr
      @ips = Yabitz::Model::IPAddress.choose(:address){|v| @network.include?(IPAddr.new(v))}
      iptable = Hash[*(@ips.map{|ip| [ip.address, ip]}.flatten)]
      @network.to_range.each{|ip| @ips.push(Yabitz::Model::IPAddress.query_or_create(:address => ip.to_s)) unless iptable[ip.to_s]}
      
      @page_title = "IPセグメント: #{@ipseg.to_s}"
      @ips.sort!
      haml :ipaddress_list
    end
  end
  # get '/ybz/ipsegment/retrospect/:oid' #TODO

  post '/ybz/ipsegment/:oid' do
    admin_protected!

    Stratum.transaction do |conn|
      seg = Yabitz::Model::IPSegment.get(params[:oid].to_i)
      pass unless seg

      unless request.params['target_id'].to_i == seg.id
        raise Stratum::ConcurrentUpdateError
      end

      case request.params['field']
      when 'ongoing'
        unless request.params['operation'] == 'toggle'
          halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
        end
        seg.ongoing = (not seg.ongoing)
      when 'notes'
        unless request.params['operation'] = 'edit'
          halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
        end
        seg.notes = request.params['value']
      else
        halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
      end
      seg.save unless seg.saved?
    end
    
    "ok"
  end

  post '/ybz/ipsegment/create' do
    admin_protected!

    if Yabitz::Model::IPSegment.query(:address => request.params['address'].strip, :count => true) > 0
      raise Yabitz::DuplicationError
    end
    seg = Yabitz::Model::IPSegment.new
    seg.set(request.params['address'].strip, request.params['mask'].to_i.to_s)

    cls_a = IPAddr.new("10.0.0.0/8")
    cls_b = IPAddr.new("172.16.0.0/12")
    cls_c = IPAddr.new("192.168.0.0/16")
    addr = IPAddr.new(seg.address + '/' + seg.netmask)
    seg.area = if cls_a.include?(addr) or cls_b.include?(addr) or cls_c.include?(addr)
                 Yabitz::Model::IPSegment::AREA_LOCAL
               else
                 Yabitz::Model::IPSegment::AREA_GLOBAL
               end
    seg.ongoing = true
    seg.save
    
    "ok"
  end

  post '/ybz/ipsegment/alter-prepare/:ope/:oid' do
    admin_protected!
    segment = Yabitz::Model::IPSegment.get(params[:oid].to_i)
    unless segment
      halt HTTP_STATUS_CONFLICT, "指定されたIPセグメントが見付かりません<br />ページを更新してやりなおしてください"
    end

    case params[:ope]
    when 'delete_records'
      network = segment.to_addr
      if Yabitz::Model::IPAddress.choose(:address, :hosts, :holder, :lowlevel => true, :oidonly => true){|addr,hosts,holder| not addr.nil? and not addr.empty? and network.include?(IPAddr.new(addr)) and not hosts.nil? and not hosts.empty? and holder == Stratum::Model::BOOL_FALSE}.size > 0
        "セグメント #{segment} において使用中のIPアドレスがありますが、強行しますか？"
      else
        "選択されたセグメント #{segment} を削除して本当にいいですか？"
      end
    else
      pass
    end
  end

  post '/ybz/ipsegment/alter-execute/:ope/:oid' do
    admin_protected!
    segment = Yabitz::Model::IPSegment.get(params[:oid].to_i)
    unless segment
      halt HTTP_STATUS_CONFLICT, "指定されたIPセグメントが見付かりません<br />ページを更新してやりなおしてください"
    end

    case params[:ope]
    when 'delete_records'
      segment_str = segment.to_s
      segment.remove()
      "完了： セグメント #{segment_str} の削除"
    else
      pass
    end
  end

  get %r!/ybz/ipaddress/list/network/([:._0-9]+\d/\d+)(\.json)?! do |network_str, ctype|
    authorized?
    @network = IPAddr.new(Yabitz::Model::IPAddress.dequote(network_str))
    @ips = Yabitz::Model::IPAddress.choose(:address){|v| @network.include?(IPAddr.new(v))}
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @ips.to_json
    else
      iptable = Hash[*(@ips.map{|ip| [ip.address, ip]}.flatten)]
      @network.to_range.each{|ip| @ips.push(Yabitz::Model::DummyIPAddress.new(ip.to_s)) unless iptable[ip.to_s]}

      @page_title = "ネットワーク内のIPアドレス: #{network_str}"
      @ips.sort!
      haml :ipaddress_list
    end
  end

  get %r!/ybz/ipaddress/(\d+_\d+_\d+_\d+)(\.tr\.ajax|\.ajax|\.json)?! do |ipaddr, ctype|
    authorized?
    @ip = Yabitz::Model::IPAddress.query(:address => Yabitz::Model::IPAddress.dequote(ipaddr), :unique => true)
    unless @ip
      @ip = Yabitz::Model::DummyIPAddress.new(Yabitz::Model::IPAddress.dequote(ipaddr))
    end

    case ctype
    when '.json'
      pass unless @ip.oid

      response['Content-Type'] = 'application/json'
      @ip.to_json
    when '.tr.ajax'
      haml :ipaddress, :layout => false, :locals => {:ipaddress => @ip}
    when '.ajax'
      haml :ipaddress_parts, :layout => false
    else
      @page_title = "IPアドレス: #{@ip.to_s}"
      require 'ipaddr'
      @ips = [@ip]
      haml :ipaddress_list
    end
  end

  get %r!/ybz/ipaddress/holder(\.json)?! do |ctype|
    authorized?
    @ips = Yabitz::Model::IPAddress.query(:holder => true)
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @ips.to_json
    else
      @page_title = "予約済みIPアドレス一覧"
      @ips.sort!
      haml :ipaddress_list
    end
  end

  get %r!/ybz/ipaddress/global(\.json)?! do |ctype|
    authorized?
    cls_a = IPAddr.new("10.0.0.0/8")
    cls_b = IPAddr.new("172.16.0.0/12")
    cls_c = IPAddr.new("192.168.0.0/16")
    @ips = Yabitz::Model::IPAddress.choose(:address){|v| ip = IPAddr.new(v); not cls_a.include?(ip) and not cls_b.include?(ip) and not cls_c.include?(ip)}
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @ips.to_json
    else
      @page_title = "グローバルIPアドレス一覧"
      @ips.sort!
      haml :ipaddress_list
    end
  end

  get %r!/ybz/ipaddress/list(\.json)?! do |ctype|
    authorized?
    @ips = Yabitz::Model::IPAddress.all
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @ips.to_json
    else
      raise NotImplementedError
    end
  end

  post %r!/ybz/ipaddress/(\d+_\d+_\d+_\d+)! do |ipaddr|
    admin_protected!

    Stratum.transaction do |conn|
      ip = Yabitz::Model::IPAddress.query_or_create(:address => Yabitz::Model::IPAddress.dequote(ipaddr))
      if request.params['target_id'] and (not request.params['target_id'].empty?) and request.params['target_id'].to_i != ip.id
        raise Stratum::ConcurrentUpdateError
      end

      case request.params['field']
      when 'holder'
        unless request.params['operation'] == 'toggle'
          halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
        end
        ip.holder = (not ip.holder)
      when 'notes'
        unless request.params['operation'] = 'edit'
          halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
        end
        ip.notes = request.params['value']
      else
        halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
      end
      ip.save unless ip.saved?
    end
    "ok"
  end

  ### rackunit, rack
  get %r!/ybz/rackunit/list(\.json)?! do |ctype|
    authorized?
    @rackunits = Yabitz::Model::RackUnit.all
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @rackunits.to_json
    else
      raise NotImplementedError
    end
  end

  get %r!/ybz/rackunit/(\d+)(\.json)?! do |oid, ctype|
    protected!
    ru = Yabitz::Model::RackUnit.get(oid.to_i)
    pass unless ru

    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      ru.to_json
    else
      unless ru.rack
        ru.rack_set
        ru.save
      end
      redirect "/ybz/rack/#{ru.rack.oid}"
    end
  end

  post '/ybz/rack/create' do
    admin_protected!
    if Yabitz::Model::Rack.query(:label => request.params['label'], :count => true) > 0
      raise Yabitz::DuplicationError
    end

    rack = Yabitz::Model::Rack.new()
    rack.label = request.params['label'].strip
    racktype = Yabitz::RackTypes.search(rack.label)
    rack.type = racktype.name
    rack.datacenter = racktype.datacenter
    rack.ongoing = true
    rack.save
    
    "ok"
  end

  get %r!/ybz/rack/list(\.json)?! do |ctype|
    authorized?
    @racks = Yabitz::Model::Rack.all
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @racks.to_json
    else
      @units_in_racks = {}
      @rack_blank_scores = nil

      @rackunits = Yabitz::Model::RackUnit.all
      Stratum.preload(@rackunits, Yabitz::Model::RackUnit)
      @rackunits.each do |ru|
        next if ru.hosts.select{|h| h.isnt(:removed, :removing)}.size < 1
        @units_in_racks[ru.rack_by_id] ||= 0
        @units_in_racks[ru.rack_by_id] += 1
      end

      @page_title = "ラック一覧"
      @racks.sort!
      haml :rack_list
    end
  end

  get %r!/ybz/rack/blanklist! do
    authorized?
    @racks = Yabitz::Model::Rack.all
    
    @units_in_racks = {}
    @rack_blank_scores = {}

    rackunits_per_rack = {}
    @rackunits = Yabitz::Model::RackUnit.all
    Stratum.preload(@rackunits, Yabitz::Model::RackUnit)
    hwinfos = Yabitz::Model::HwInformation.all
    @rackunits.each do |ru|
      next if ru.hosts.select{|h| h.isnt(:removed, :removing)}.size < 1
      rackunits_per_rack[ru.rack_by_id] ||= []
      rackunits_per_rack[ru.rack_by_id].push(ru)
      @units_in_racks[ru.rack_by_id] ||= 0
      @units_in_racks[ru.rack_by_id] += 1
    end
    @racks.each do |rack|
      racktype = Yabitz::RackTypes.search(rack.label)
      @rack_blank_scores[rack.oid] = racktype.rackunit_status_list(rack.label, (rackunits_per_rack[rack.oid] || []))
    end

    @page_title = "ラック一覧"
    @racks.sort!{|a,b| ((a.datacenter <=> b.datacenter) != 0) ? a.datacenter <=> b.datacenter : @rack_blank_scores[b.oid].first <=> @rack_blank_scores[a.oid].first}
    haml :rack_list
  end

  get %r!/ybz/rack/(\d+)(\.tr\.ajax|\.ajax|\.json)?! do |oid, ctype|
    authorized?
    @rack = Yabitz::Model::Rack.get(oid.to_i)
    pass unless @rack

    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @rack.to_json
    when '.tr.ajax'
      rackunits = Yabitz::Model::RackUnit.query(:rack => @rack).select{|ru| ru.hosts.select{|h| h.isnt(:removing, :removed)}.size > 0}
      @units_in_racks = {@rack.oid => rackunits.size}
      @rack_blank_scores = {@rack.oid => Yabitz::RackTypes.search(@rack.label).rackunit_status_list(@rack.label, rackunits)}
      haml :rack, :layout => false, :locals => {:rack => @rack}
    when '.ajax'
      haml :rack_parts, :layout => false
    else
      @hosts = Yabitz::Model::RackUnit.query(:rack => @rack).map(&:hosts).flatten
      Stratum.preload(@hosts, Yabitz::Model::Host)
      @units = {}
      racktype = Yabitz::RackTypes.search(@rack.label)
      @hosts.each do |host|
        next if host.hosttype.virtualmachine? or host.status == Yabitz::Model::Host::STATUS_REMOVED
        @units[host.rackunit.rackunit] = host
        if host.hwinfo and host.hwinfo.unit_height > 1
          racktype.upper_rackunit_labels(host.rackunit.rackunit, host.hwinfo.unit_height - 1).each{|pos| @units[pos] = host}
        end
      end
      @page_title = "ラック #{@rack.label} の状況"
      @hide_detailview = true
      haml :rack_show
    end
  end

  post '/ybz/rack/:oid' do
    admin_protected!

    Stratum.transaction do |conn|
      rack = Yabitz::Model::Rack.get(params[:oid].to_i)
      pass unless rack

      unless request.params['target_id'].to_i == rack.id
        raise Stratum::ConcurrentUpdateError
      end

      case request.params['field']
      when 'ongoing'
        unless request.params['operation'] == 'toggle'
          halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
        end
        rack.ongoing = (not rack.ongoing)
      when 'notes'
        unless request.params['operation'] = 'edit'
          halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
        end
        rack.notes = request.params['value']
      else
        halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
      end
      rack.save unless rack.saved?
    end
    
    "ok"
  end
  
  post '/ybz/rack/alter-prepare/:ope/:oid' do
    admin_protected!
    rack = Yabitz::Model::Rack.get(params[:oid].to_i)
    unless rack
      halt HTTP_STATUS_CONFLICT, "指定されたラックが見付かりません<br />ページを更新してやりなおしてください"
    end

    case params[:ope]
    when 'delete_records'
      if Yabitz::Model::RackUnit.query(:rack => rack).select{|ru| ru.hosts_by_id.size > 0}.size > 0
        halt HTTP_STATUS_NOT_ACCEPTABLE, "(撤去済みのものも含めて)<br />このラック所属のホストが存在したままです"
      end
      "選択されたラック #{rack} を削除して本当にいいですか？"
    else
      pass
    end
  end

  post '/ybz/rack/alter-execute/:ope/:oid' do
    admin_protected!
    rack = Yabitz::Model::Rack.get(params[:oid].to_i)
    unless rack
      halt HTTP_STATUS_CONFLICT, "指定されたラックが見付かりません<br />ページを更新してやりなおしてください"
    end
    rackunits = Yabitz::Model::RackUnit.query(:rack => rack)

    case params[:ope]
    when 'delete_records'
      rack_str = rack.to_s
      Stratum.transaction do |conn|
        rackunits.each do |ru|
          halt HTTP_STATUS_CONFLICT, "ラックに所属ホストが存在したままです: 更新が衝突した可能性があります" if ru.hosts_by_id > 0
          ru.rack = nil
          ru.save
          ru.remove
        end
      end
      rack.remove
      "完了： ラック #{rack_str} の削除"
    else
      pass
    end
  end
  # get '/ybz/rackunit/retrospect/:oid' #TODO
  # get '/ybz/rack/retrospect/:oid' #TODO


  # get '/ybz/dnsname/:oid' #TODO
  # get '/ybz/dnsname/retrospect/:oid' #TODO
  # get '/ybz/dnsname/floating' #TODO
  # delete '/ybz/dnsname/:oid' #TODO

  ### OSおよびハードウェア情報
  get %r!/ybz/osinfo/list(.json)?! do |ctype|
    authorized?
    @osinfos = Yabitz::Model::OSInformation.all
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @osinfos.to_json
    else
      @page_title = "OS情報一覧"
      @osinfos.sort!
      haml :osinfo_list
    end
  end

  post '/ybz/osinfo/create' do
    admin_protected!

    if Yabitz::Model::OSInformation.query(:name => request.params['name'], :count => true) > 0
      raise Yabitz::DuplicationError
    end
    osinfo = Yabitz::Model::OSInformation.new()
    osinfo.name = request.params['name'].strip
    osinfo.save
    
    "ok"
  end

  # delete '/ybz/osinfo/:oid' #TODO

  get %r!/ybz/hwinfo/list(\.json)?! do |ctype|
    authorized?
    @hwinfos = Yabitz::Model::HwInformation.all
    # Stratum.preload(@hwinfos, Yabitz::Model::Host) # has no ref/reflist field.
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @hwinfos.to_json
    else
      @page_title = "ハードウェア情報一覧"
      @hwinfos.sort!
      haml :hwinfo_list
    end
  end

  post '/ybz/hwinfo/create' do 
    admin_protected!
    if Yabitz::Model::HwInformation.query(:name => request.params['name'], :count => true) > 0
      raise Yabitz::DuplicationError
    end
    hwinfo = Yabitz::Model::HwInformation.new()
    hwinfo.name = request.params['name'].strip
    hwinfo.units = request.params['units'].strip
    hwinfo.calcunits = (request.params['calcunits'].strip == "" ? hwinfo.units_calculated : request.params['calcunits'].strip)
    hwinfo.virtualized = (request.params['virtualized'] and request.params['virtualized'].strip == 'on')

    if not hwinfo.virtualized and hwinfo.calcunits.to_f == 0.0
      raise Yabitz::InconsistentDataError.new("ユニット数なしは仮想化サーバの場合のみ可能です")
    end
    hwinfo.save
    
    "ok"
  end
  
  # delete '/ybz/hwinfo/:oid' #TODO

  ### 運用状況
  # 筐体/OS別の台数/ユニット数
  
  get %r!/ybz/machines/hardware/(\d+)\.ajax! do |oid|
    authorized?
    @hwinfo = Yabitz::Model::HwInformation.get(oid.to_i)
    @all_services = Yabitz::Model::Service.all
    @service_count_map = {}
    @all_services.each do |service|
      num = Yabitz::Model::Host.query(:service => service, :hwinfo => @hwinfo, :count => true)
      @service_count_map[service.oid] = num if num > 0
    end
    haml :machine_hw_service_parts, :layout => false
  end

  get %r!/ybz/machines/hardware(\.tsv)?! do |ctype|
    authorized?
    @hws = Yabitz::Model::HwInformation.all.sort

    case ctype
    when '.tsv' then raise NotImplementedError
    else
      @hide_selectionbox = true
      @page_title = "筐体別使用状況"
      haml :machine_hardware
    end
  end

  get %r!/ybz/machines/os/(.+)\.ajax! do |osname_raw|
    authorized?
    @osname = unescape(CGI.unescapeHTML(osname_raw))
    @all_services = Yabitz::Model::Service.all
    @service_count_map = {}
    @all_services.each do |service|
      num = Yabitz::Model::Host.query(:service => service, :os => (@osname == 'NULL' ? '' : @osname), :count => true)
      @service_count_map[service.oid] = num if num > 0
    end
    haml :machine_os_service_parts, :layout => false
  end

  get %r!/ybz/machines/os(\.tsv)?! do |ctype|
    authorized?
    @osnames = Yabitz::Model::OSInformation.os_in_hosts.sort

    case ctype
    when '.tsv' then raise NotImplementedError
    else
      @hide_selectionbox = true
      @page_title = "OS別使用状況"
      haml :machine_os
    end
  end

  ### 課金状況
  # 全体
  get %r!/ybz/charge/summary(\.tsv)?! do |ctype|
    authorized?
    @depts = Yabitz::Model::Dept.all
    @contents = Yabitz::Model::Content.all
    @services = Yabitz::Model::Service.all
    @hosts = Yabitz::Model::Host.all
    tmp3 = Yabitz::Model::HwInformation.all

    @status, @types, @chargings, @dept_counts, @content_counts = Yabitz::Charging.calculate(@hosts)

    case ctype
    when '.tsv' then raise NotImplementedError
    else
      @hide_selectionbox = true
      @page_title = "課金用情報サマリ"
      haml :charge_summary
    end
  end
  # コンテンツごと
  get %r!/ybz/charge/content/(\d+)\.ajax! do |oid|
    authorized?
    
    @content = Yabitz::Model::Content.get(oid.to_i)
    @content_charges = Yabitz::Charging.calculate_content(@content)
    haml :charge_content_parts, :layout => false
  end

  ### ユーザ情報 (すべて認証要求、post/putはadmin)
  get '/ybz/auth_info/list' do
    protected!
    all_users = Yabitz::Model::AuthInfo.all.sort
    valids = []
    invalids = []
    all_users.each do |u|
      if u.valid? and not u.root?
        valids.push(u)
      elsif not u.root?
        invalids.push(u)
      end
    end
    @users = valids + invalids
    @page_title = "ユーザ認証情報一覧"
    haml :auth_info_list
  end

  get %r!/ybz/auth_info/(\d+)(\.ajax|\.tr\.ajax)?! do |oid, ctype|
    protected!
    @auth_info = Yabitz::Model::AuthInfo.get(oid.to_i)
    pass unless @auth_info # object not found -> HTTP 404

    case ctype
    when '.ajax' then haml :auth_info_parts, :layout => false
    when '.tr.ajax' then haml :auth_info, :layout => false, :locals => {:auth_info => @auth_info}
    else
      raise NotImplementedError
    end
  end
  
  post '/ybz/auth_info/:oid' do
    admin_protected!
    user = Yabitz::Model::AuthInfo.get(params[:oid].to_i)
    pass unless user

    case request.params['operation']
    when 'toggle'
      case request.params['field']
      when 'priv'
        if user.admin?
          user.priv = nil
        else
          user.set_admin
        end
      when 'valid'
        user.valid = (not user.valid?)
      end
    end
    user.save
    "ok"
  end
  # post '/ybz/auth_info/invalidate' #TODO

  ### 部署等 (post/put/deleteはすべてadmin認証要求)
  get %r!/ybz/dept/list(\.json)?! do |ctype|
    authorized?
    @depts = Yabitz::Model::Dept.all.sort
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @depts.to_json
    else
      @page_title = "部署一覧"
      haml :dept_list
    end
  end

  post '/ybz/dept/create' do
    admin_protected!
    if Yabitz::Model::Dept.query(:name => request.params['name'].strip, :count => true) > 0
      raise Yabitz::DuplicationError
    end
    dept = Yabitz::Model::Dept.new()
    dept.name = request.params['name'].strip
    dept.save
    "ok"
  end
  get %r!/ybz/dept/(\d+)(\.json|\.tr\.ajax|\.ajax)?! do |oid, ctype|
    authorized?
    
    @dept = Yabitz::Model::Dept.get(oid.to_i)
    pass unless @dept # object not found -> 404

    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @dept.to_json
    when '.ajax' then haml :dept_parts, :layout => false
    when '.tr.ajax' then haml :dept, :layout => false, :locals => {:dept => @dept}
    else
      @hide_detailbox = true
      @page_title = "部署: #{@dept.name}"
      haml :dept_page, :locals => {:cond => @page_title}
    end
  end

  post %r!/ybz/dept/(\d+)! do |oid|
    admin_protected!

    Stratum.transaction do |conn|
      @dept = Yabitz::Model::Dept.get(oid.to_i)
      pass unless @dept
      if request.params['target_id']
        unless request.params['target_id'].to_i == @dept.id
          raise Stratum::ConcurrentUpdateError
        end
      end
      field = request.params['field'].to_sym
      @dept.send(field.to_s + '=', @dept.map_value(field, request))
      @dept.save
    end
    
    "ok"
  end
  # delete '/ybz/dept/:oid' #TODO

  get %r!/ybz/content/list(\.json)?! do |ctype|
    authorized?
    @contents = Yabitz::Model::Content.all.sort
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @contents.to_json
    else
      @page_title = "コンテンツ一覧"
      haml :content_list
    end
  end

  post %r!/ybz/content/create! do
    admin_protected!
    if Yabitz::Model::Content.query(:name => request.params['name'].strip, :count => true) > 0
      raise Yabitz::DuplicationError
    end
    content = Yabitz::Model::Content.new()
    content.name = request.params['name'].strip
    content.charging = request.params['charging'].strip
    content.code = request.params['code'].strip
    content.dept = Yabitz::Model::Dept.get(request.params['dept'].strip.to_i)
    content.save
    redirect '/ybz/content/list'
  end
  get %r!/ybz/content/(\d+)(\.json|\.tr\.ajax|\.ajax)?! do |oid, ctype|
    authorized?
    @content = Yabitz::Model::Content.get(oid.to_i)
    pass unless @content # object not found -> HTTP 404

    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @content.to_json
    when '.ajax' then haml :content_parts, :layout => false
    when '.tr.ajax' then haml :content, :layout => false, :locals => {:content => @content}
    else
      Stratum.preload([@content], Yabitz::Model::Content)
      @hide_detailbox = true
      @page_title = "コンテンツ: #{@content.name}"
      haml :content_page, :locals => {:cond => @page_title}
    end
  end
  post %r!/ybz/content/(\d+)! do |oid|
    admin_protected!

    Stratum.transaction do |conn|
      @content = Yabitz::Model::Content.get(oid.to_i)
      pass unless @content
      if request.params['target_id']
        unless request.params['target_id'].to_i == @content.id
          raise Stratum::ConcurrentUpdateError
        end
      end
      field = request.params['field'].to_sym
      @content.send(field.to_s + '=', @content.map_value(field, request))
      @content.save
    end
    
    "ok"
  end
  # delete '/ybz/content/:oid' #TODO
  
  get %r!/ybz/service/list(\.json)?! do |ctype|
    authorized?
    @services = Yabitz::Model::Service.all
    Stratum.preload(@services, Yabitz::Model::Service)
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @services.to_json
    else
      @services.sort!
      @page_title = "サービス"
      haml :services
    end
  end

  post '/ybz/service/create' do
    admin_protected!
    if Yabitz::Model::Service.query(:name => request.params['name'].strip, :count => true) > 0
      raise Yabitz::DuplicationError
    end
    service = Yabitz::Model::Service.new
    service.name = request.params['name'].strip
    service.content = Yabitz::Model::Content.get(request.params['content'].to_i)
    service.mladdress = request.params['mladdress'].strip
    service.save
    redirect '/ybz/service/list'
  end

  get %r!/ybz/service/(\d+)(\.json|\.ajax|\.tr\.ajax)?! do |oid, ctype|
    authorized?
    @srv = Yabitz::Model::Service.get(oid.to_i)
    pass unless @srv # object not found -> HTTP 404

    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @srv.to_json
    when '.ajax' then haml :service_parts, :layout => false
    when '.tr.ajax' then haml :service, :layout => false, :locals => {:service => @srv}
    else
      @page_title = "サービス: #{@srv.name}"
      @service_single = true
      @services = [@srv]
      Stratum.preload(@services, Yabitz::Model::Service)
      haml :services
    end
  end

  post %r!/ybz/service/(\d+)! do |oid|
    protected!

    Stratum.transaction do |conn|
      @srv = Yabitz::Model::Service.get(oid.to_i)
      pass unless @srv
      if request.params['target_id']
        unless request.params['target_id'].to_i == @srv.id
          raise Stratum::ConcurrentUpdateError
        end
      end

      field = request.params['field'].to_sym
      unless @isadmin or field == :contact or field == :notes
        halt HTTP_STATUS_FORBIDDEN, "not authorized"
      end

      @srv.send(field.to_s + '=', @srv.map_value(field, request))
      @srv.save

      if field == :contact
        Yabitz::Plugin.get(:handler_hook).each do |plugin|
          if plugin.respond_to?(:contact_update)
            plugin.contact_update(@srv.contact)
          end
        end
      end
    end
    "ok"
  end
  # delete '/ybz/service/:oid' #TODO

  post '/ybz/service/alter-prepare/:ope/:oid' do
    admin_protected!
    oid = params[:oid].to_i
    service = Yabitz::Model::Service.get(oid)
    unless service
      halt HTTP_STATUS_CONFLICT, "指定されたサービスが見付かりません<br />ページを更新してやりなおしてください"
    end

    case params[:ope]
    when 'change_content'
      content_select_tag_template = <<EOT
%div 変更先コンテンツを選択してください
%div
  %select{:name => "content"}
    - Yabitz::Model::Content.all.sort.each do |content|
      %option{:value => content.oid}&= content.to_s
EOT
      haml content_select_tag_template, :layout => false
    when 'delete_records'
      if Yabitz::Model::Host.query(:service => service, :count => true) > 0
        halt HTTP_STATUS_NOT_ACCEPTABLE, "該当サービスに所属しているホストがあるため削除できません"
      end
      "選択されたサービス #{service.name} のデータを削除して本当にいいですか？"
    else
      pass
    end
  end

  post '/ybz/service/alter-execute/:ope/:oid' do
    admin_protected!
    oid = params[:oid].to_i
    service = Yabitz::Model::Service.get(oid)
    unless service
      halt HTTP_STATUS_CONFLICT, "指定されたサービスが見付かりません<br />ページを更新してやりなおしてください"
    end

    case params[:ope]
    when 'change_content'
      content = Yabitz::Model::Content.get(params[:content].to_i)
      halt HTTP_STATUS_CONFLICT, "指定されたサービスが見付かりませんでした" unless content

      service.content = content
      service.save
      "完了： サービス #{service.name} の #{content.to_s} への変更"
    when 'delete_records'
      servicename = service.name
      Stratum.transaction do |conn|
        if Yabitz::Model::Host.query(:service => service, :count => true) > 0
          halt HTTP_STATUS_NOT_ACCEPTABLE, "該当サービスに所属しているホストがあるため削除できません"
        end

        content = service.content
        content.services_by_id = content.services_by_id - [service.oid]
        content.save

        service.urls = []
        service.contact = nil
        service.save()
        
        service.remove()
      end
      "完了： サービス #{servicename} の削除"
    else
      pass
    end
  end
  
  ### 連絡先

  get %r!/ybz/contact/list(\.json)?! do |ctype|
    protected!
    @contacts = Yabitz::Model::Contact.all.sort
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @contacts.to_json
    else
      @page_title = "連絡先一覧"
      haml :contact_list
    end
  end

  # get '/ybz/contact/create' #TODO
  # post '/ybz/contact/create' #TODO

  get %r!/ybz/contact/(\d+)(\.json)?! do |oid, ctype|
    protected!
    @contact = Yabitz::Model::Contact.get(oid.to_i)
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @contact.to_json
    else
      @page_title = "連絡先: #{@contact.label}"
      Stratum.preload([@contact], Yabitz::Model::Contact)
      haml :contact_page, :locals => {:cond => @page_title}
    end
  end

  post '/ybz/contact/:oid' do |oid|
    protected!
    pass if request.params['editstyle'].nil? or request.params['editstyle'].empty?

    case request.params['editstyle']
    when 'fields_edit'
      Stratum.transaction do |conn|
        @contact = Yabitz::Model::Contact.get(oid.to_i)
        pass unless @contact
        if request.params['target_id']
          raise Stratum::ConcurrentUpdateError unless request.params['target_id'].to_i == @contact.id
        end
        ['label', 'telno_daytime', 'mail_daytime', 'telno_offtime', 'mail_offtime', 'memo'].each do |field_string|
          unless @contact.send(field_string) == request.params[field_string].strip
            @contact.send(field_string + '=', request.params[field_string].strip)
          end
        end
        @contact.save unless @contact.saved?
        Yabitz::Plugin.get(:handler_hook).each do |plugin|
          if plugin.respond_to?(:contact_update)
            plugin.contact_update(@contact)
          end
        end
      end
    when 'add_with_create'
      Stratum.transaction do |conn|
        @contact = Yabitz::Model::Contact.get(oid.to_i)
        pass unless @contact
        if request.params['target_id']
          raise Stratum::ConcurrentUpdateError unless request.params['target_id'].to_i == @contact.id
        end
        if request.params['badge'] and not request.params['badge'].empty?
          if Yabitz::Model::ContactMember.query(:badge => request.params['badge'].strip).size > 0
            halt HTTP_STATUS_NOT_ACCEPTABLE, "入力された社員番号と同一のメンバ情報が既にあるため、そちらを検索から追加してください"
          end
        end
        unless request.params['name']
          halt HTTP_STATUS_NOT_ACCEPTABLE, "名前の入力のない登録はできません"
        end
        member = Yabitz::Model::ContactMember.new
        member.name = request.params['name'].strip
        member.telno = request.params['telno'].strip if request.params['telno']
        member.mail = request.params['mail'].strip if request.params['mail']
        member.badge = request.params['badge'].strip.to_i.to_s unless request.params['badge'].nil? or request.params['badge'].empty?
        if not member.badge
          hit_members = Yabitz::Model::ContactMember.find_by_fullname_list([member.name.delete(' 　')])
          if hit_members.size == 1
            member_entry = hit_members.first
            member.badge = member_entry[:badge]
            member.position = member_entry[:position]
          end
        else
          hit_members = Yabitz::Model::ContactMember.find_by_fullname_and_badge_list([[member.name.delete(' 　'), member.badge]])
          if hit_members.size == 1
            member_entry = hit_members.first
            member.position = member_entry[:position]
          end
        end
        @contact.members_by_id += [member.oid]
        @contact.save
        member.save

        Yabitz::Plugin.get(:handler_hook).each do |plugin|
          if plugin.respond_to?(:contactmember_update)
            plugin.contactmember_update(member)
          end
          if plugin.respond_to?(:contact_update)
            plugin.contact_update(@contact)
          end
        end
      end
    when 'add_with_search'
      Stratum.transaction do |conn|
        @contact = Yabitz::Model::Contact.get(oid.to_i)
        pass unless @contact
        if request.params['target_id']
          raise Stratum::ConcurrentUpdateError unless request.params['target_id'].to_i == @contact.id
        end
        if request.params['adding_contactmember']
          if request.params['adding_contactmember'] == 'not_selected'
            halt HTTP_STATUS_NOT_ACCEPTABLE, "追加するメンバを選択してください"
          end
          member = Yabitz::Model::ContactMember.get(request.params['adding_contactmember'].to_i)
          halt HTTP_STATUS_NOT_ACCEPTABLE, "指定された連絡先メンバが存在しません" unless member
          halt HTTP_STATUS_NOT_ACCEPTABLE, "指定された連絡先メンバは既にリストに含まれています" if @contact.members_by_id.include?(member.oid)
          @contact.members_by_id += [member.oid]
        else
          # space and full-width-space deleted.
          name_compacted_string = (request.params['name'] and not request.params['name'].empty?) ? request.params['name'].strip : nil
          badge_number = (request.params['badge'] and not request.params['badge'].empty?) ? request.params['badge'].tr('０-９　','0-9 ').strip.to_i : nil
          member = if name_compacted_string and badge_number
                     Yabitz::Model::ContactMember.query(:name => name_compacted_string, :badge => badge_number.to_s)
                   elsif name_compacted_string
                     if name_compacted_string =~ /[ 　]/
                       first_part, last_part = name_compacted_string.split(/[ 　]/)
                       Yabitz::Model::ContactMember.regex_match(:name => /#{first_part}[ 　]*#{last_part}/)
                     else
                       Yabitz::Model::ContactMember.query(:name => name_compacted_string)
                     end
                   elsif badge_number
                     Yabitz::Model::ContactMember.query(:badge => badge_number.to_s)
                   else
                     halt HTTP_STATUS_NOT_ACCEPTABLE, "検索条件を少なくともどちらか入力してください"
                   end
          halt HTTP_STATUS_NOT_ACCEPTABLE, "入力された条件に複数のメンバが該当するため追加できません" if member.size > 1
          halt HTTP_STATUS_NOT_ACCEPTABLE, "入力された条件にどのメンバも該当しません" if member.size < 1
          member = member.first
          @contact.members_by_id += [member.oid]
        end
        @contact.save
        Yabitz::Plugin.get(:handler_hook).each do |plugin|
          if plugin.respond_to?(:contact_update)
            plugin.contact_update(@contact)
          end
        end
      end
    when 'edit_memberlist'
      Stratum.transaction do |conn|
        @contact = Yabitz::Model::Contact.get(oid.to_i)
        pass unless @contact
        if request.params['target_id']
          raise Stratum::ConcurrentUpdateError unless request.params['target_id'].to_i == @contact.id
        end
        original_oid_order = @contact.members_by_id
        reorderd_list = []
        removed_list = []
        request.params.keys.select{|k| k =~ /\Aorder_of_\d+\Z/}.each do |key|
          target = key.gsub(/order_of_/,'').to_i
          order_index_string = request.params[key]
          if order_index_string.nil? or order_index_string.empty?
            removed_list.push(target)
          else
            order_index = order_index_string.to_i - 1
            halt HTTP_STATUS_NOT_ACCEPTABLE, "順序は1以上の数で指定してください" if order_index < 0
            if original_oid_order[order_index] != target
              if reorderd_list[order_index].nil?
                reorderd_list[order_index] = target
              else
                afterpart = reorderd_list[order_index + 1, reorderd_list.size]
                re_order_index = order_index + 1 + (afterpart.index(nil) || afterpart.size)
                reorderd_list[re_order_index] = target
              end
            end
          end
        end
        original_oid_order.each do |next_oid|
          next if removed_list.include?(next_oid) or reorderd_list.include?(next_oid)
          next_blank_index = reorderd_list.index(nil) || reorderd_list.size
          reorderd_list[next_blank_index] = next_oid
        end
        reorderd_list.compact!
        if original_oid_order != reorderd_list
          @contact.members_by_id = reorderd_list
          @contact.save

          Yabitz::Plugin.get(:handler_hook).each do |plugin|
            if plugin.respond_to?(:contact_update)
              plugin.contact_update(@contact)
            end
          end
        end
      end
    end
    "連絡先 #{@contact.label} の情報を変更しました"
  end
  # delete '/ybz/contact/:oid' #TODO

  get %r!/ybz/contactmember/list(\.json)?! do |ctype|
    protected!
    @contactmembers = Yabitz::Model::ContactMember.all.sort
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @contactmembers.to_json
    else
      @page_title = "連絡先メンバ一覧"
      haml :contactmember_list
    end
  end

  # get '/ybz/contactmember/create' #TODO
  # post '/ybz/contactmember/create' #TODO

  get %r!/ybz/contactmember/(\d+)(\.json|\.ajax|\.tr.ajax)?! do |oid, ctype|
    protected!
    @contactmember = Yabitz::Model::ContactMember.get(oid.to_i)
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @contactmember.to_json
    when '.ajax'
      haml :contactmember_parts, :layout => false
    when '.tr.ajax'
      haml :contactmember, :layout => false, :locals => {:contactmember => @contactmember}
    else
      @contactmembers = [@contactmember]
      @page_title = "連絡先メンバ表示：" + @contactmember.name
      haml :contactmember_list
    end
  end

  post %r!/ybz/contactmember/(\d+)! do |oid|
    protected!
    Stratum.transaction do |conn|
      @member = Yabitz::Model::ContactMember.get(oid.to_i)

      pass unless @member
      if request.params['target_id']
        unless request.params['target_id'].to_i == @member.id
          raise Stratum::ConcurrentUpdateError
        end
      end
      field = request.params['field'].to_sym
      @member.send(field.to_s + '=', @member.map_value(field, request))
      @member.save

      Yabitz::Plugin.get(:handler_hook).each do |plugin|
        if plugin.respond_to?(:contactmember_update)
          plugin.contactmember_update(@member)
        end
      end

    end
    "ok"
  end

  post '/ybz/contactmember/alter-prepare/:ope/:oidlist' do
    admin_protected!
    oidlist = params[:oidlist].split('-').map(&:to_i)
    members = Yabitz::Model::ContactMember.get(oidlist)
    unless oidlist.size == members.size
      halt HTTP_STATUS_CONFLICT, "指定された連絡先メンバの全部もしくは一部が見付かりません<br />ページを更新してやりなおしてください"
    end
    case params[:ope]
    when 'remove_data'
      "指定された連絡先メンバをすべての連絡先から取り除き、データを削除します"
    when 'update_from_source'
      if members.select{|m| (m.name.nil? or m.name.empty?) and (m.badge.nil? or m.badge.empty?)}.size > 0
        halt HTTP_STATUS_NOT_ACCEPTABLE, "氏名も社員番号も入力されていないメンバがあり、検索できません"
      end
      "指定された連絡先メンバの氏名と社員番号・職種を連携先から取得して更新します"
    when 'combine_each'
      "指定された連絡先メンバのうち、氏名と電話番号、メールアドレスが一致するものを統合します"
    else
      pass
    end
  end

  post '/ybz/contactmember/alter-execute/:ope/:oidlist' do
    admin_protected!
    oidlist = params[:oidlist].split('-').map(&:to_i)
    members = Yabitz::Model::ContactMember.get(oidlist)
    unless oidlist.size == members.size
      halt HTTP_STATUS_CONFLICT, "指定された連絡先メンバの全部もしくは一部が見付かりません<br />ページを更新してやりなおしてください"
    end
    case params[:ope]
    when 'remove_data'
      Stratum.transaction do |conn|
        Yabitz::Model::Contact.all.each do |contact|
          if (contact.members_by_id & oidlist).size > 0
            contact.members_by_id = (contact.members_by_id - oidlist)
            contact.save
          end
        end
        members.each do |member|
          member.remove
        end
      end
      "#{oidlist.size}件の連絡先メンバを削除しました"
    when 'update_from_source'
      name_only = []
      badge_only = []
      fully_qualified = []

      members.each do |m|
        if m.name and not m.name.empty? and m.badge and not m.badge.empty?
          fully_qualified.push([m, [m.name.delete(' 　'), m.badge.to_i]]) # delete space, and full-width space
        elsif m.name and not m.name.empty?
          name_only.push([m, m.name.delete(' 　')]) # delete space, and full-width space
        elsif m.badge and not m.badge.empty?
          badge_only.push([m, m.badge.to_i])
        end
      end

      def update_member(member, entry)
        return unless entry
        
        if entry[:fullname] and member.name.delete(' 　') != entry[:fullname]
          member.name = entry[:fullname]
        end
        if entry[:badge] and entry[:badge].to_i != member.badge.to_i
          member.badge = entry[:badge].to_s
        end
        if entry[:position] and entry[:position] != member.position
          member.position = entry[:position]
        end
        member.save unless member.saved?
      end

      Stratum.transaction do |conn|
        if name_only.size > 0
          memlist, namelist = name_only.transpose
          entries = Yabitz::Model::ContactMember.find_by_fullname_list(namelist)
          entries.each_index do |i|
            update_member(memlist[i], entries[i])
          end
        end
        if badge_only.size > 0
          memlist, badgelist = badge_only.transpose
          entries = Yabitz::Model::ContactMember.find_by_badge_list(badgelist)
          entries.each_index do |i|
            update_member(memlist[i], entries[i])
          end
        end
        if fully_qualified.size > 0
          memlist, pairlist = fully_qualified.transpose
          entries = Yabitz::Model::ContactMember.find_by_fullname_and_badge_list(pairlist)
          entries.each_index do |i|
            update_member(memlist[i], entries[i])
          end
        end
      end
      "連絡先メンバの更新に成功しました"
    when 'combine_each'
      combined = {}
      members.each do |member|
        combkey = member.name + '/' + member.telno + '/' + member.mail
        combined[combkey] = [] unless combined[combkey]
        combined[combkey].push(member)
      end
      oid_map = []
      all_combined_oids = []
      Stratum.transaction do |conn|
        combined.each do |key, list|
          next if list.size < 2
          c = Yabitz::Model::ContactMember.new
          c.name = list.first.name
          c.telno = list.first.telno
          c.mail = list.first.mail
          c.comment = list.map(&:comment).compact.join("\n")
          c.save
          oid_map.push([list.map(&:oid), c.oid])
          all_combined_oids += list.map(&:oid)
        end

        Yabitz::Model::Contact.all.each do |contact|
          next if (contact.members_by_id & all_combined_oids).size < 1

          member_id_list = contact.members_by_id
          member_id_list.each_index do |index|
            oid_map.each do |from_id_list, to_id|
              if from_id_list.include?(member_id_list[index])
                member_id_list[index] = to_id
              end
            end
          end
          contact.members_by_id = member_id_list
          contact.save
        end
        members.each do |member|
          member.remove if all_combined_oids.include?(member.oid)
        end
      end
      "指定された連絡先メンバの統合を実行しました"
    else
      pass
    end
  end

  # delete '/ybz/contactmembers/:oid' #TODO


  get '/ybz/brick/create' do
    admin_protected!
    @page_title = "機器追加"
    haml :brick_create
  end

  post '/ybz/brick/create' do
    admin_protected!
    params = request.params
    Stratum.transaction do |conn|
      params.keys.select{|k| k =~ /\Aadding\d+\Z/}.each do |key|
        i = params[key].to_i.to_s
        brick = Yabitz::Model::Brick.new
        brick.productname = params["productname#{i}"].strip
        brick.hwid = params["hwid#{i}"].strip
        brick.serial = params["serial#{i}"].strip
        brick.heap = params["heap#{i}"].strip
        brick.delivered = params["delivered"]
        brick.status = params["status"]
        brick.save
      end
    end
    "ok"
  end

  get '/ybz/brick/bulkcreate' do
    admin_protected!
    @page_title = "機器追加(CSV/TSV)"
    haml :brick_bulkcreate
  end
  
  post '/ybz/brick/bulkcreate' do
    admin_protected!
    status = request.params["status"]
    datalines = request.params["dataarea"].split("\n")
    raise Yabitz::InconsistentDataError, "データが空です" if datalines.empty?
    splitter = if datalines.first.include?("\t")
                 lambda {|l| l.split("\t")}
               else
                 require 'csv'
                 lambda {|l| l.parse_csv}
               end
    Stratum.transaction do |conn|
      datalines.each do |line|
        next if line.empty? or line.length < 1
        p, s, d, h = splitter.call(line)
        raise Yabitz::InconsistentDataError, "不足しているフィールドがあります" unless p and s and d and h
        brick = Yabitz::Model::Brick.new
        brick.productname = p
        brick.hwid = h
        brick.serial = s
        brick.delivered = d
        brick.status = status
        brick.save
      end
    end
    "ok"
  end

  get %r!/ybz/bricks/list/all(\.json|\.csv)?! do |ctype|
    authorized?
    @bricks = Yabitz::Model::Brick.all
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @bricks.to_json
    when '.csv'
      response['Content-Type'] = 'text/csv'
      Yabitz::Model::Brick.build_raw_csv(Yabitz::Model::Brick::CSVFIELDS, @bricks)
    else
      @bricks.sort!
      @page_title = "機器一覧 (全て)"
      haml :bricks, :locals => {:cond => '全て'}
    end
  end

  get %r!/ybz/brick/list/hosts/([-0-9]+)(\.json|\.csv)?! do |host_oidlist, ctype|
    authorized?
    hosts = Yabitz::Model::Host.get(host_oidlist.split('-').map(&:to_i))
    pass if hosts.empty? # object not found -> HTTP 404

    hwidlist = []
    hosts.each do |h|
      if h.hwid and h.hwid.length > 1
        hwidlist.push(h.hwid)
      end
    end
    @bricks = Yabitz::Model::Brick.choose(:hwid){|hwid| hwidlist.delete(hwid)}
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @bricks.to_json
    when '.csv'
      response['Content-Type'] = 'text/csv'
      Yabitz::Model::Brick.build_raw_csv(Yabitz::Model::Brick::CSVFIELDS, @bricks)
    else
      @bricks.sort!
      @page_title = "機器一覧 (選択ホストから)"
      @default_selected_all = true
      haml :bricks, :locals => {:cond => "選択ホストから"}
    end
  end

  get %r!/ybz/bricks/list/(stock|in_use|spare|repair|broken)(\.json|\.csv)?! do |statuslabel, ctype|
    authorized?
    targetstatus = case statuslabel
                   when 'stock'  then Yabitz::Model::Brick::STATUS_STOCK
                   when 'in_use' then Yabitz::Model::Brick::STATUS_IN_USE
                   when 'spare'  then Yabitz::Model::Brick::STATUS_SPARE
                   when 'repair' then Yabitz::Model::Brick::STATUS_REPAIR
                   when 'broken' then Yabitz::Model::Brick::STATUS_BROKEN
                   end
    @bricks = Yabitz::Model::Brick.query(:status => targetstatus)
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @bricks.to_json
    when '.csv'
      response['Content-Type'] = 'text/csv'
      Yabitz::Model::Brick.build_raw_csv(Yabitz::Model::Brick::CSVFIELDS, @bricks)
    else
      @bricks.sort!
      statustitle = Yabitz::Model::Brick.status_title(targetstatus)
      @page_title = "機器一覧 (#{statustitle})"
      haml :bricks, :locals => {:cond => statustitle}
    end
  end

  get %r!/ybz/brick/hwid/(.*)(\.json|\.csv)?! do |hwid, ctype|
    authorized?
    @bricks = Yabitz::Model::Brick.query(:hwid => hwid)
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @bricks.to_json
    when '.csv'
      response['Content-Type'] = 'text/csv'
      Yabitz::Model::Brick.build_raw_csv(Yabitz::Model::Brick::CSVFIELDS, @bricks)
    else
      @bricks.sort!
      @page_title = "機器一覧 (HWID: #{CGI.escapeHTML(hwid)})"
      haml :bricks, :locals => {:cond => 'HWID:' + hwid}
    end
  end

  get %r!/ybz/brick/([-0-9]+)(\.ajax|\.tr\.ajax|\.json|\.csv)?! do |oidlist, ctype|
    authorized?
    @bricks = Yabitz::Model::Brick.get(oidlist.split('-').map(&:to_i))
    pass if @bricks.empty? # object not found -> HTTP 404
    case ctype
    when '.ajax'
      @brick = @bricks.first
      haml :brick_parts, :layout => false
    when '.tr.ajax'
      haml :brick, :layout => false, :locals => {:brick => @bricks.first}
    when '.json'
      response['Content-Type'] = 'application/json'
      @bricks.to_json
    when '.csv'
      response['Content-Type'] = 'text/csv'
      Yabitz::Model::Brick.build_raw_csv(Yabitz::Model::Brick::CSVFIELDS, @bricks)
    else
      @page_title = "機器一覧"
      haml :bricks, :locals => {:cond => '機器: ' + @bricks.map{|b| CGI.escapeHTML(b.to_s)}.join(', ')}
    end
  end

  post '/ybz/brick/:oid' do 
    protected!
    Stratum.transaction do |conn|
      @brick = Yabitz::Model::Brick.get(params[:oid].to_i)
      pass unless @brick
      if request.params['target_id']
        unless request.params['target_id'].to_i == @brick.id
          raise Stratum::ConcurrentUpdateError
        end
      end
      field = request.params['field'].to_sym
      @brick.send(field.to_s + '=', @brick.map_value(field, request))
      @brick.save
    end
    "ok"
  end

  post '/ybz/brick/alter-prepare/:ope/:oidlist' do
    admin_protected!
    oidlist = params[:oidlist].split('-').map(&:to_i)
    bricks = Yabitz::Model::Brick.get(oidlist)
    unless oidlist.size == bricks.size
      halt HTTP_STATUS_CONFLICT, "指定された機器の全部もしくは一部が見付かりません<br />ページを更新してやりなおしてください"
    end
    
    case params[:ope]
    when 'status_in_use', 'status_repair', 'status_broken', 'status_stock'
      st_title = Yabitz::Model::Brick.status_title(params[:ope] =~ /\Astatus_(.+)\Z/ ? $1.upcase : nil)
      "状態: #{st_title} へ変更していいですか？"
    when 'status_spare'
      if bricks.select{|b| b.heap.nil? or b.heap == ''}.size > 0
        halt HTTP_STATUS_NOT_ACCEPTABLE, "指定された機器に置き場所不明のものがあります<br />入力してからやりなおしてください"
      end
      "状態 #{Yabitz::Model::Brick.status_title(Yabitz::Model::Brick::STATUS_SPARE)} へ変更していいですか？"
    when 'set_heap'
      set_heap_template = <<EOT
%div 選択した機器の置き場所を入力してください
%div
  %input{:type => "text", :name => "heap", :size => 16}
EOT
      haml set_heap_template, :layout => false
    when 'set_served'
      set_served_template = <<EOT
%div 選択した機器の利用開始日を入力してください
%div
  %input{:type => "text", :name => "served", :size => 16}
EOT
      haml set_served_template, :layout => false
    when 'delete_records'
      "選択された機器すべてのデータを削除して本当にいいですか？<br />" + bricks.map{|brick| h(brick.to_s)}.join('<br />')
    else
      pass
    end
  end
  
  post '/ybz/brick/alter-execute/:ope/:oidlist' do
    admin_protected!
    oidlist = params[:oidlist].split('-').map(&:to_i)
    bricks = Yabitz::Model::Brick.get(oidlist)
    unless oidlist.size == bricks.size
      halt HTTP_STATUS_CONFLICT, "指定された機器の全部もしくは一部が見付かりません<br />ページを更新してやりなおしてください"
    end
    
    case params[:ope]
    when 'status_in_use', 'status_repair', 'status_broken', 'status_stock'
      raise ArgumentError, params[:ope] unless params[:ope] =~ /\Astatus_(.+)\Z/ and Yabitz::Model::Brick::STATUS_LIST.include?($1.upcase)
      new_status = $1.upcase
      Stratum.transaction do |conn|
        bricks.each do |brick|
          brick.status = new_status
          brick.save
        end
      end
    when 'status_spare'
      raise ArgumentError if bricks.select{|b| b.heap.nil? or b.heap == ''}.size > 0
      Stratum.transaction do |conn|
        bricks.each do |brick|
          brick.status = Yabitz::Model::Brick::STATUS_SPARE
          brick.save
        end
      end
    when 'set_heap'
      Stratum.transaction do |conn|
        bricks.each do |brick|
          brick.heap = params[:heap]
          brick.save
        end
      end
    when 'set_served'
      Stratum.transaction do |conn|
        bricks.each do |brick|
          brick.served = params[:served]
          brick.save
        end
      end
    when 'delete_records'
      Stratum.transaction do |conn|
        bricks.each do |brick|
          brick.remove
        end
      end
    else
      pass
    end
    'ok'
  end

  get '/ybz/brick/history/:oidlist' do |oidlist|
    authorized?
    @brick_records = []
    oidlist.split('-').map(&:to_i).each do |oid|
      @brick_records += Yabitz::Model::Brick.retrospect(oid)
    end
    @brick_records.sort!{|a,b| ((b.inserted_at.to_i <=> a.inserted_at.to_i) != 0) ? (b.inserted_at.to_i <=> a.inserted_at.to_i) : (b.id.to_i <=> a.id.to_i)}
    @oidlist = oidlist
    @hide_detailview = true
    haml :brick_history
  end

  get %r!/ybz/brick/served(\/([-0-9]+)(\/([-0-9]+))?)?(\.json|\.csv)?! do |dummy1, from, dummy2, to, ctype|
    authorized?
    @served_records = nil
    from = params[:from] if not from and params[:from]
    to = params[:to] if not to and params[:to] and params[:to].length > 0

    if from and from.length > 0
      raise ArgumentError, "invalid from" unless from and from =~ /^\d\d\d\d-\d\d-\d\d$/
      raise ArgumentError, "invalid to" unless to.nil? or to =~ /^\d\d\d\d-\d\d-\d\d$/
      to = Time.now.strftime('%Y-%m-%d') if to.nil?
      @served_records = Yabitz::Model::Brick.served_between(from, to)
    end
    case ctype
    when '.json'
      raise NotImplementedError, "hmmmm...."
    when '.csv'
      raise NotImplementedError, "hmmmm...."
    else
      @from_param = from
      @to_param = to
      @page_title = "機器利用開始リスト"
      haml :brick_served, :locals => {:from => from, :to => to}
    end
  end

  get '/ybz/yabitz.css' do
    authorized?
    content_type 'text/css', :charset => 'utf-8'
    sass :yabitz
  end

  get %!/ybz/top_toggle! do
    authorized?
    if session[:toppage] and session[:toppage] == 'googlelike'
      session[:toppage] = nil
    else
      session[:toppage] = 'googlelike'
    end
    redirect '/ybz'
  end

  get %r!\A/ybz/?\Z! do 
    authorized?
    @hide_detailview = true
    haml :toppage
  end

  get %r!\A/\Z! do
    redirect '/ybz'
  end

  Yabitz::Plugin.get(:handler).each do |plugin|
    if plugin.respond_to?(:addhandlers)
      plugin.addhandlers(self)
    end
  end

  not_found do 
    "指定の操作が定義にないか、または操作対象のoidが存在しません"
  end

  error Yabitz::DuplicationError do
    halt HTTP_STATUS_CONFLICT, "そのデータは既に存在しています"
  end

  error Yabitz::InconsistentDataError do
    halt HTTP_STATUS_NOT_ACCEPTABLE, CGI.escapeHTML(request.env['sinatra.error'].message)
  end

  error Stratum::FieldValidationError do
    msg = CGI.escapeHTML(request.env['sinatra.error'].message)
    if request.env['sinatra.error'].model and request.env['sinatra.error'].field
      ex = request.env['sinatra.error'].model.ex(request.env['sinatra.error'].field)
      if ex and not ex.empty?
        msg += "<br />" + CGI.escapeHTML(ex)
      end
    end
    halt HTTP_STATUS_NOT_ACCEPTABLE, msg
  end

  error Stratum::ConcurrentUpdateError do 
    halt HTTP_STATUS_CONFLICT, "他の人とWeb更新操作が衝突しました<br />ページを更新してからやり直してください"
  end

  error Stratum::TransactionOperationError do 
    halt HTTP_STATUS_CONFLICT, "他の人と処理が衝突しました<br />ページを更新してからやり直してください"
  end

  Yabitz::Plugin.get(:error_handler).each do |plugin|
    if plugin.respond_to?(:adderrorhandlers)
      plugin.adderrorhandlers(self)
    end
  end

  # error do 
  # end
end

if ENV['RACK_ENV'].to_sym == :development or ENV['RACK_ENV'].to_sym == :importtest
  Yabitz::Application.run! :host => '0.0.0.0', :port => 8180
end
