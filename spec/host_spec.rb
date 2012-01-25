# -*- coding: utf-8 -*-

$YABITZ_RUN_ON_TEST_ENVIRONMENT = true

require_relative '../lib/yabitz/misc/init'
require_relative '../scripts/db_schema'
require_relative '../lib/yabitz/model/host'
require_relative '../lib/yabitz/model'
require_relative '../lib/yabitz/misc/hosttype'

describe Yabitz::Model::Host do 
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end

  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  before do
    @cls = Yabitz::Model::Host
    @t = @cls.new
  end

  it "の #<=> が正常にDNS名、localipの先頭、globalipの先頭、rackunit、hwid、oidの順になるよう値を返すこと" do
    t2 = @cls.new
    t2.save
    @t.save
    (@t <=> t2).should eql(-1) # ascending with oid

    @t.hwid = 'A0002'
    (@t <=> t2).should eql(-1)
    t2.hwid = 'A0001'
    (@t <=> t2).should eql(1) # dictionary order with hwid, stronger than oid ordering
    @t.hwid = 'MS315'
    t2.hwid = 'MS315'
    (@t <=> t2).should eql(-1)

      /\A[a-zA-Z][0-9]{2}-(0[1-9]|[1-3][0-9]|4[012])[fr]?\Z/
    @t.rackunit = Yabitz::Model::RackUnit.query_or_create(:rackunit => 'a01-12')
    (@t <=> t2).should eql(-1)
    t2.rackunit = Yabitz::Model::RackUnit.query_or_create(:rackunit => 'a01-10')
    (@t <=> t2).should eql(1)
    @t.rackunit = nil
    t2.rackunit = nil
    (@t <=> t2).should eql(-1)

    @t.globalips = Yabitz::Model::IPAddress.query_or_create(:address => '0.0.0.2')
    (@t <=> t2).should eql(-1)
    t2.globalips = Yabitz::Model::IPAddress.query_or_create(:address => '0.0.0.1')
    (@t <=> t2).should eql(1)
    @t.globalips = []
    t2.globalips = []
    (@t <=> t2).should eql(-1)

    @t.localips = Yabitz::Model::IPAddress.query_or_create(:address => '10.172.10.128')
    (@t <=> t2).should eql(-1)
    t2.localips = Yabitz::Model::IPAddress.query_or_create(:address => '10.172.10.18')
    (@t <=> t2).should eql(1)
    @t.localips = []
    t2.localips = []
    (@t <=> t2).should eql(-1)

    @t.dnsnames = Yabitz::Model::DNSName.query_or_create(:dnsname => 'hoge.5.pos')
    (@t <=> t2).should eql(-1)
    t2.dnsnames = Yabitz::Model::DNSName.query_or_create(:dnsname => 'hoge.3.pos')
    (@t <=> t2).should eql(1)
    @t.dnsnames = Yabitz::Model::DNSName.query_or_create(:dnsname => 'hoge.2.pos.xen')
    (@t <=> t2).should eql(-1)
    t2.dnsnames = Yabitz::Model::DNSName.query_or_create(:dnsname => 'db.hoge.2.pos')
    (@t <=> t2).should eql(1)
  end

  it "の .normalize_memory がメモリ単位の表記をMB/GB/TB/MiB/GiB/TiBに修正すること" do
    @cls.normalize_memory('５１２ＭＢ').should eql('512MB')
    @cls.normalize_memory('０．５Ｇｂ').should eql('0.5GB')
    @cls.normalize_memory('32 GB').should eql('32GB')
    @cls.normalize_memory('１　ｔｂ').should eql('1TB')
    @cls.normalize_memory('500mib').should eql('500MiB')
    @cls.normalize_memory('５００　ｍｉｂ').should eql('500MiB')
    @cls.normalize_memory('500m').should eql('500MB')
  end

  it "の .normalize_disk がディスク容量単位および台数、RAID表記の揺れを修正すること" do
    @cls.normalize_disk('ＨＤＤ　５００ＧＢ').should eql('HDD 500GB')
    @cls.normalize_disk('ＳＳＤ １２８ＧＢ').should eql('SSD 128GB')
    @cls.normalize_disk('ＨＤＤ　２ＴＢｘ２').should eql('HDD 2TB x2')
    @cls.normalize_disk('ＨＤＤ １．５ＴＢ ＊ ２').should eql('HDD 1.5TB x2')
    @cls.normalize_disk('ＳＳＤ４００ＧＢx2').should eql('SSD 400GB x2')
    @cls.normalize_disk('ＨＤＤ　２ＴＢｘ４　ＲＡＩＤ−５').should eql('HDD 2TB x4 RAID-5')
    @cls.normalize_disk('HDD500GBRAID1').should eql('HDD 500GB RAID-1')
    @cls.normalize_disk('SATA2TBx5 RAID-5').should eql('SATA 2TB x5 RAID-5')
    @cls.normalize_disk('SSD 400GB*8 RAID 6').should eql('SSD 400GB x8 RAID-6')
    @cls.normalize_disk('HDD 1.5 TB * 2 RAIDZ').should eql('HDD 1.5TB x2 RAID-Z')
    @cls.normalize_disk('SSD400GBx4RAID1+0').should eql('SSD 400GB x4 RAID-1+0')

    @cls.normalize_disk('５００Ｇ').should eql('500GB')
    @cls.normalize_disk('ＳＳＤ １２８Ｇ').should eql('SSD 128GB')
    @cls.normalize_disk('ＨＤＤ　２Ｔｘ２').should eql('HDD 2TB x2')
    @cls.normalize_disk('１．５Ｔ ＊ ２').should eql('1.5TB x2')
    @cls.normalize_disk('ＳＳＤ４００Ｇx2').should eql('SSD 400GB x2')
    @cls.normalize_disk('ＨＤＤ　２Ｔｘ４　ＲＡＩＤ−５').should eql('HDD 2TB x4 RAID-5')
    @cls.normalize_disk('HDD500GRAID1').should eql('HDD 500GB RAID-1')
    @cls.normalize_disk('2Tx5 RAID-5').should eql('2TB x5 RAID-5')
    @cls.normalize_disk('SSD 400G*8 RAID 6').should eql('SSD 400GB x8 RAID-6')
    @cls.normalize_disk('HDD 1.5 T * 2 RAIDZ').should eql('HDD 1.5TB x2 RAID-Z')
    @cls.normalize_disk('SSD400Gx4RAID1+0').should eql('SSD 400GB x4 RAID-1+0')
  end

  it "に #status が正常に入出力可能で、値は既定の選択肢からのみセットできること" do
    lambda {@t.status = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.status = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.status = '停止'}.should raise_exception(Stratum::FieldValidationError)

    @t.status = @cls::STATUS_UNDER_DEV
    @t.status = @cls::STATUS_IN_SERVICE
    @t.status = @cls::STATUS_NO_COUNT
    @t.status = @cls::STATUS_SUSPENDED
    @t.status = @cls::STATUS_REMOVING
    @t.status = @cls::STATUS_REMOVED
    @t.status = @cls::STATUS_MISSING
    @t.status = @cls::STATUS_OTHER
  end

  it "に #type が正常に入出力可能で、nilおよび空文字列でない、16文字以下のみに制限されること" do
    lambda {@t.type = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.type = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.type = 'a'*16}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.type = 'あ'*16}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.type = Yabitz::HostType.names.first}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.type = Yabitz::HostType.names.last}.should_not raise_exception(Stratum::FieldValidationError)
  end
  
  it "に #hwid が正常に入出力可能で、nilおよび空文字の許された16文字以下であること" do 
    lambda {@t.hwid = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hwid.should eql('')
    lambda {@t.hwid = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hwid.should eql('')

    lambda {@t.hwid = 'a'*17}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.hwid = 'あ'*17}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.hwid = 'a'*16}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.hwid = 'あ'*16}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hwid = 'X23579'
    @t.hwid.should eql('X23579')
  end

  it "に #cpu が正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.cpu = ''}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.cpu = nil}.should_not raise_exception(Stratum::FieldValidationError)

    lambda {@t.cpu = '4'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.cpu.should eql('4')
    lambda {@t.cpu = '16'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.cpu.should eql('16')
    lambda {@t.cpu = '4 Intel Xeon'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.cpu.should eql('4 Intel Xeon')
    lambda {@t.cpu = '2 2.4GHz'}.should_not raise_exception(Stratum::FieldValidationError)
    
    lambda {@t.cpu = '４'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.cpu.should eql('4')
    lambda {@t.cpu = '１６'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.cpu = '４　Ｉｎｔｅｌ　Ｘｅｏｎ'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.cpu.should eql('4 Intel Xeon')
    lambda {@t.cpu = '２ ２．４ＧＨｚ'}.should_not raise_exception(Stratum::FieldValidationError)
  end

  it "に #memory が正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.memory = ''}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.memory = nil}.should_not raise_exception(Stratum::FieldValidationError)

    lambda {@t.memory = '512MB'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.memory = '500MiB'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.memory = '32GB'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.memory = '1TB'}.should_not raise_exception(Stratum::FieldValidationError)
    
    lambda {@t.memory = '1.5GB'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.memory = '700MiB'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.memory = '1000GiB'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.memory = '0.2TiB'}.should_not raise_exception(Stratum::FieldValidationError)

    lambda {@t.memory = '５１２ＭＢ'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.memory.should eql('512MB')
    lambda {@t.memory = '０．５Ｇｂ'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.memory.should eql('0.5GB')
    lambda {@t.memory = '32 GB'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.memory.should eql('32GB')
    lambda {@t.memory = '１　ｔｂ'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.memory.should eql('1TB')
  end

  it "に #disk が正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.disk = ''}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.disk = nil}.should_not raise_exception(Stratum::FieldValidationError)

    lambda {@t.disk = 'HDD 500GB'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.disk = 'SSD 128GB'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.disk = 'HDD 2TB'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.disk = 'SAS 2TB x2'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.disk = 'SATA 1.5TB x2'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.disk = 'SSD 400GB x2'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.disk = 'HDD 1PB'}.should_not raise_exception(Stratum::FieldValidationError)

    lambda {@t.disk = 'ＨＤＤ　５００ＧＢ'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.disk.should eql('HDD 500GB')
    lambda {@t.disk = 'ＳＳＤ １２８ＧＢ'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.disk.should eql('SSD 128GB')
    lambda {@t.disk = 'ＨＤＤ　２ＴＢｘ２'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.disk.should eql('HDD 2TB x2')
    lambda {@t.disk = 'ＨＤＤ １．５ＴＢ ＊ ２'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.disk.should eql('HDD 1.5TB x2')
    lambda {@t.disk = 'ＳＳＤ４００ＧＢx2'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.disk.should eql('SSD 400GB x2')

    lambda {@t.disk = '500G'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.disk = 'SSD 128gb'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.disk.should eql('SSD 128GB')
    lambda {@t.disk = 'SSD 128'}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.disk = 'HDD 1.5TB *2'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.disk.should eql('HDD 1.5TB x2')
    lambda {@t.disk = 'HDD 2TB+2TB'}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.disk = 'SSD'}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.disk = 'HDD 500GB RAID-1'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.disk = 'HDD 2TB x5 RAID-5'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.disk = 'SSD 400GB x8 RAID-6'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.disk = 'HDD 1.5TB x2 RAID-1+0'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.disk = 'SSD 400GB x2 RAID-10'}.should_not raise_exception(Stratum::FieldValidationError)

    lambda {@t.disk = 'HDD500GBRAID1'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.disk.should eql('HDD 500GB RAID-1')
    lambda {@t.disk = 'SATA2TBx5 RAID-5'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.disk.should eql('SATA 2TB x5 RAID-5')
    lambda {@t.disk = 'SSD 400GB*8 RAID 6'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.disk.should eql('SSD 400GB x8 RAID-6')
    lambda {@t.disk = 'HDD 1.5TB * 2 RAID-Z'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.disk.should eql('HDD 1.5TB x2 RAID-Z')
    lambda {@t.disk = 'SSD400GBx4RAID1+0'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.disk.should eql('SSD 400GB x4 RAID-1+0')
  end

  it "に #os が正常に入出力可能で、nilおよび空文字の許された64文字以下であること" do 
    lambda {@t.os = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.os.should eql('')
    lambda {@t.os = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.os.should eql('')

    lambda {@t.os = 'a'*65}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.os = 'あ'*65}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.os = 'a'*64}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.os = 'あ'*64}.should_not raise_exception(Stratum::FieldValidationError)
    @t.os = 'Debian GNU/Linux 5.0'
    @t.os.should eql('Debian GNU/Linux 5.0')
  end

  it "に #notes が正常に入出力可能で、nilおよび空文字の許された1024文字以下であること" do 
    lambda {@t.notes = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('')
    lambda {@t.notes = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('')

    lambda {@t.notes = 'a'*4097}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.notes = 'あ'*4097}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.notes = 'a'*4096}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.notes = 'あ'*4096}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes = 'めもめも memo めも'
    @t.notes.should eql('めもめも memo めも')
  end

  it "の #parent に対して Host のセットおよび取り出しが正常に行えること" do
    h = @cls.new
    h.service_by_id = 0
    h.status = @cls::STATUS_IN_SERVICE
    h.type = Yabitz::HostType::TYPES.select{|t| t[:type] == Yabitz::HostType::HV}.first[:name]
    h.save

    lambda {@t.parent = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.parent.should be_nil

    @t.parent_by_id = 5
    @t.parent_by_id.should eql(5)
    @t.parent = h
    @t.parent_by_id.should eql(h.oid)
    @t.parent.oid.should eql(h.oid)
  end
  
  it "の #children に対して Host のリストのセットおよび取り出しが正常に行えること" do
    h1 = @cls.new
    h1.service_by_id = 0
    h1.status = @cls::STATUS_UNDER_DEV
    type1 = Yabitz::HostType::TYPES.select{|t| t[:type] == Yabitz::HostType::VM}.first[:name]
    h1.type = type1
    h1.save
    h2 = @cls.new
    h2.service_by_id = 0
    h2.status = @cls::STATUS_NO_COUNT
    h2.type = type1
    h2.save

    lambda {@t.children = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.children.should eql([])
    lambda {@t.shildren = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.children.should eql([])

    @t.children_by_id = [10,20,30,5]
    @t.children_by_id.should eql([10,20,30,5])
    @t.children = [h2, h1]
    @t.children_by_id.should eql([h2.oid, h1.oid])
    @t.children.map(&:type).should eql([type1, type1])
  end
  
  it "の #rackunit に対して RackUnit のセットおよび取り出しが正常に行えること" do
    ra = Yabitz::Model::Rack.new
    ra.label = 'x80'
    ra.type = Yabitz::Plugin::StandardRack42U.name
    ra.datacenter = Yabitz::Plugin::StandardRack42U.datacenter
    ra.save
    ru = Yabitz::Model::RackUnit.new
    ru.rackunit = 'x80-01'
    ru.dividing = Yabitz::RackTypes::DIVIDING_FULL
    ru.rack = ra
    ru.save

    lambda {@t.rackunit = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.rackunit.should be_nil

    @t.rackunit_by_id = 99
    @t.rackunit_by_id.should eql(99)

    @t.rackunit = ru
    @t.rackunit_by_id.should eql(ru.oid)
    @t.rackunit.oid.should eql(ru.oid)
    @t.rackunit.rackunit.should eql('x80-01')
    @t.rackunit.rack.label.should eql('x80')
  end
  
  it "の #hwinfo に対して HwInformation のセットおよび取り出しが正常に行えること" do
    hi = Yabitz::Model::HwInformation.query_or_create(:name => 'AM3', :units => '1U(HALF)')

    lambda {@t.hwinfo = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hwinfo.should be_nil

    @t.hwinfo_by_id = 1099
    @t.hwinfo_by_id.should eql(1099)

    @t.hwinfo = hi
    @t.hwinfo_by_id.should eql(hi.oid)
    @t.hwinfo.oid.should eql(hi.oid)
    @t.hwinfo.name.should eql('AM3')
    @t.hwinfo.units.should eql('1U(HALF)')
  end
  
  it "の #dnsnames に対して DNSName のリストのセットおよび取り出しが正常に行えること" do
    dn2 = Yabitz::Model::DNSName.query_or_create(:dnsname => 'yabitzdb.log.xen')
    dn1 = Yabitz::Model::DNSName.query_or_create(:dnsname => 'yabitz.log.xen')
    dn3 = Yabitz::Model::DNSName.query_or_create(:dnsname => 'kinglog-adm.log.xen')

    lambda {@t.dnsnames = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.dnsnames.should eql([])
    lambda {@t.dnsnames = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.dnsnames.should eql([])

    @t.dnsnames_by_id = [2041, 1019, 4117, 3]
    @t.dnsnames_by_id.should eql([2041, 1019, 4117, 3])

    @t.dnsnames = [dn1, dn2, dn3]
    @t.dnsnames_by_id.should eql([dn1.oid, dn2.oid, dn3.oid])
    @t.dnsnames.map(&:oid).should eql([dn1.oid, dn2.oid, dn3.oid])
    @t.dnsnames.map(&:dnsname).should eql(['yabitz.log.xen', 'yabitzdb.log.xen', 'kinglog-adm.log.xen'])
  end
  
  it "の #localips に対して IPAddress のリストのセットおよび取り出しが正常に行えること" do
    ip3 = Yabitz::Model::IPAddress.query_or_create(:address => '10.0.0.1')
    ip2 = Yabitz::Model::IPAddress.query_or_create(:address => '172.16.0.1')
    ip1 = Yabitz::Model::IPAddress.query_or_create(:address => '192.168.0.1')

    lambda {@t.localips = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.localips.should eql([])
    lambda {@t.localips = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.localips.should eql([])

    @t.localips_by_id = [27, 3, 1009]
    @t.localips_by_id.should eql([27, 3, 1009])

    @t.localips = [ip1, ip2, ip3]
    @t.localips_by_id.should eql([ip1.oid, ip2.oid, ip3.oid])
    @t.localips.map(&:oid).should eql([ip1.oid, ip2.oid, ip3.oid])
    @t.localips.map(&:address).should eql(['192.168.0.1', '172.16.0.1', '10.0.0.1'])
  end
  
  it "の #globalips に対して IPAddress のリストのセットおよび取り出しが正常に行えること" do
    ip3 = Yabitz::Model::IPAddress.query_or_create(:address => '10.0.0.1')
    ip2 = Yabitz::Model::IPAddress.query_or_create(:address => '172.16.0.1')
    ip1 = Yabitz::Model::IPAddress.query_or_create(:address => '192.168.0.1')

    lambda {@t.globalips = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.globalips.should eql([])
    lambda {@t.globalips = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.globalips.should eql([])

    @t.globalips_by_id = [27, 3, 1009]
    @t.globalips_by_id.should eql([27, 3, 1009])

    @t.globalips = [ip1, ip2, ip3]
    @t.globalips_by_id.should eql([ip1.oid, ip2.oid, ip3.oid])
    @t.globalips.map(&:oid).should eql([ip1.oid, ip2.oid, ip3.oid])
    @t.globalips.map(&:address).should eql(['192.168.0.1', '172.16.0.1', '10.0.0.1'])
  end
  
  it "の #virtualips に対して IPAddress のリストのセットおよび取り出しが正常に行えること" do
    ip3 = Yabitz::Model::IPAddress.query_or_create(:address => '10.0.0.1')
    ip2 = Yabitz::Model::IPAddress.query_or_create(:address => '172.16.0.1')
    ip1 = Yabitz::Model::IPAddress.query_or_create(:address => '192.168.0.1')

    lambda {@t.virtualips = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.virtualips.should eql([])
    lambda {@t.virtualips = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.virtualips.should eql([])

    @t.virtualips_by_id = [27, 3, 1009]
    @t.virtualips_by_id.should eql([27, 3, 1009])

    @t.virtualips = [ip1, ip2, ip3]
    @t.virtualips_by_id.should eql([ip1.oid, ip2.oid, ip3.oid])
    @t.virtualips.map(&:oid).should eql([ip1.oid, ip2.oid, ip3.oid])
    @t.virtualips.map(&:address).should eql(['192.168.0.1', '172.16.0.1', '10.0.0.1'])
  end
  
  it "の #tagchain に対して TagChain のセットおよび取り出しが正常に行えること" do
    tc = Yabitz::Model::TagChain.new
    tc.tagchain = ['App', 'memcache', 'blog-new', '20100902xapv']
    tc.save

    lambda {@t.tagchain = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.tagchain.should be_nil

    @t.tagchain_by_id = 9908
    @t.tagchain_by_id.should eql(9908)

    @t.tagchain = tc
    @t.tagchain_by_id.should eql(tc.oid)
    @t.tagchain.oid.should eql(tc.oid)
    @t.tagchain.tagchain.should eql(['App', 'memcache', 'blog-new', '20100902xapv'])
  end

  it "の #display_name によってホストの表示名が正常に取得できること" do
    @t.display_name.should match(/\Aunknown host oid:\d+\Z/)

    @t.hwid = "X9999"
    @t.save
    @t.display_name.should eql("hwid:X9999")

    @t.rackunit = Yabitz::Model::RackUnit.query_or_create(:rackunit => "z09-14", :rack => Yabitz::Model::Rack.query_or_create(:label => "z09"))
    @t.save
    @t.display_name.should eql("rackunit:z09-14")

    @t.globalips = Yabitz::Model::IPAddress.query_or_create(:address => "125.6.172.15")
    @t.save
    @t.display_name.should eql("global:125.6.172.15")

    @t.globalips += [Yabitz::Model::IPAddress.query_or_create(:address => "125.6.172.16")]
    @t.save
    @t.globalips_by_id.size.should eql(2)
    @t.display_name.should eql("global:125.6.172.15")

    @t.localips = Yabitz::Model::IPAddress.query_or_create(:address => "10.0.208.150")
    @t.save
    @t.display_name.should eql("local:10.0.208.150")

    @t.dnsnames = Yabitz::Model::DNSName.query_or_create(:dnsname => "www01.top.xen")
    @t.save
    @t.display_name.should eql("www01.top.xen")

    @t.dnsnames = [Yabitz::Model::DNSName.query_or_create(:dnsname => "testapp01.top.xen")] + @t.dnsnames
    @t.save
    @t.display_name.should eql("testapp01.top.xen")
  end

  it "に .query_tag したとき、正常にクエリしたタグを持っているHostが取得できること" do
    def makehost_has_tags(tags)
      h1 = Yabitz::Model::Host.new
      h1.service_by_id = 0
      h1.status = Yabitz::Model::Host::STATUS_IN_SERVICE
      h1.type = Yabitz::HostType.names.first
      h1.save
      
      t1 = Yabitz::Model::TagChain.new
      t1.host = h1
      t1.tagchain = tags
      t1.save

      h1.tagchain = t1
      h1.save
    end

    makehost_has_tags(['hoge', 'pos', '20100901-18:30:20'])
    makehost_has_tags(['Web', 'blog', 'dev', '20100901-18:30:20'])
    makehost_has_tags(['App', 'blog', 'memcache', '20100901-18:30:20'])
    makehost_has_tags(['dbm', 'blog', 'pos', 'dev', '20100901-18:30:20'])

    @cls.query_tag('Web').size.should eql(1)
    @cls.query_tag('blog').size.should eql(3)
    @cls.query_tag('memcache').size.should eql(1)
    @cls.query_tag('dev').size.should eql(2)
    @cls.query_tag('pos').size.should eql(2)
    @cls.query_tag('20100901-18:30:20').size.should eql(4)
  end
end
