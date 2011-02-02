# -*- coding: utf-8 -*-

$YABITZ_RUN_ON_TEST_ENVIRONMENT = true

require_relative '../lib/yabitz/misc/init'
require_relative '../scripts/db_schema'
require_relative '../lib/yabitz/model/addresses'

describe Yabitz::Model::ServiceURL do
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end

  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  before do
    @cls = Yabitz::Model::ServiceURL
    @t = @cls.new
  end

  it "の normalizer が正常にHTTPスキーマの補完を行い、ホスト名部分を小文字に正規化すること" do
    @cls.normalize_url('www.livedoor.com').should eql('http://www.livedoor.com')
    @cls.normalize_url('Http://WWW.livedoor.Com').should eql('http://www.livedoor.com')
    @cls.normalize_url('hoge.pos/moge').should eql('http://hoge.pos/moge')
    @cls.normalize_url('https://secure.livedoor.jp').should eql('https://secure.livedoor.jp')
    @cls.normalize_url('live-door.net').should eql('http://live-door.net')
    @cls.normalize_url('t.co/dfaioejwafoe').should eql('http://t.co/dfaioejwafoe')
  end
  
  it "の validator が不正なURLを拒否すること" do
    @t.check_url('').should be_false
    @t.check_url(nil).should be_false

    @t.check_url('a.b').should be_false
    @t.check_url('tou.ch').should be_false
    @t.check_url('live-door.net').should be_false

    @t.check_url('http://a.b').should be_true
    @t.check_url('http://tou.ch').should be_true
    @t.check_url('http://live-door.net').should be_true
    @t.check_url('https://a.b').should be_true
    @t.check_url('https://tou.ch').should be_true
    @t.check_url('https://live-door.net').should be_true
    @t.check_url('http://a.b/').should be_true
    @t.check_url('http://tou.ch/').should be_true
    @t.check_url('http://live-door.net/').should be_true
    @t.check_url('https://a.b/').should be_true
    @t.check_url('https://tou.ch/').should be_true
    @t.check_url('https://live-door.net/').should be_true

    @t.check_url('http://live_door.net').should be_false

    @t.check_url('http://blog.livedoor.jp?hoge=pos&moge=koe%23dmogefweoai/:happy').should be_true
  end

  it "に url が正常に入出力可能なこと、またnormalizerおよびvalidatorのチェックを通っていること" do
    lambda {@t.url = ""}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.url = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.url = "live_door.jp"}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.url = "ftp://hoge.moge/"}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.url = "htp://livedoor.com/hoge"}.should raise_exception(Stratum::FieldValidationError)

    @t.url = "livedoor.jp"
    @t.url.should eql('http://livedoor.jp')
    @t.url = "live-door.jp"
    @t.url.should eql('http://live-door.jp')

    @t.url = 'www.livedoor.com'
    @t.url.should eql('http://www.livedoor.com')
    @t.url = 'Http://WWW.livedoor.Com'
    @t.url.should eql('http://www.livedoor.com')
    @t.url = 'Http://WWW.livedoor.Com/Hoge'
    @t.url.should eql('http://www.livedoor.com/Hoge')
    @t.url = 'hoge.pos/moge'
    @t.url.should eql('http://hoge.pos/moge')
    @t.url = 'https://secure.livedoor.jp'
    @t.url.should eql('https://secure.livedoor.jp')
    @t.url = 'live-door.net'
    @t.url.should eql('http://live-door.net')
    @t.url = 't.co/dfaioejwafoe'
    @t.url.should eql('http://t.co/dfaioejwafoe')
  end
  
  it "に services のリストとして空リストおよびnilが入力可能なこと" do
    @t.services.should eql([])
    @t.services = nil
    @t.services.should eql([])
    @t.services = []
    @t.services.should eql([])
  end

  it "に services のリストが id で入出力可能なこと" do
    @t.services_by_id.should eql([])
    @t.services_by_id = nil
    @t.services_by_id.should eql([])
    @t.services_by_id = []
    @t.services_by_id.should eql([])

    @t.services_by_id = [10, 123, 555]
    @t.services_by_id.should eql([10,123,555])
  end
end

describe Yabitz::Model::DNSName do
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end

  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  before do
    @cls = Yabitz::Model::DNSName
    @t = @cls.new
  end

  it "にdns名が正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.dnsname = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.dnsname = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.dnsname = ' '}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.dnsname = 'hoge.pos.xen'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.dnsname.should eql('hoge.pos.xen')
  end

  it "にhostのリストとして空リストおよびnilが入力可能なこと" do
    @t.hosts_by_id.should eql([])

    lambda {@t.hosts_by_id = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts_by_id.should eql([])
    lambda {@t.hosts_by_id = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts_by_id.should eql([])
    lambda {@t.hosts = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts.should eql([])
    lambda {@t.hosts = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts.should eql([])
  end

  it "にhostのリストがidで入出力可能なこと" do
    lambda {@t.hosts_by_id = [1,2,3,4]}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts_by_id.should eql([1,2,3,4])
  end
end

describe Yabitz::Model::IPAddress do
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end

  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  before do
    @cls = Yabitz::Model::IPAddress
    @t = @cls.new
  end

  it "にIPアドレスが正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.address = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.address = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.address = ' '}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.address = '192.168.0.1'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.address.should eql('192.168.0.1')
  end

  it "に #version が正常に入出力可能なこと、またv4/v6以外のものが入れられないこと" do
    lambda {@t.version = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.version = ""}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.version = "4"}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.version = @cls::IPv4}.should_not raise_exception(Stratum::FieldValidationError)
    @t.version.should eql(Yabitz::Model::IPAddress::IPv4)
    lambda {@t.version = @cls::IPv6}.should_not raise_exception(Stratum::FieldValidationError)
    @t.version.should eql(Yabitz::Model::IPAddress::IPv6)
  end

  it "に #set を用いてIPアドレスが正常に入力可能なこと、また #version が同時に正しくセットされること" do
    lambda {@t.set('')}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.set('192.168.0.1')}.should_not raise_exception(Stratum::FieldValidationError)
    @t.address.should eql('192.168.0.1')
    @t.version.should eql(Yabitz::Model::IPAddress::IPv4)
    lambda {@t.set('100d::fff0')}.should_not raise_exception(Stratum::FieldValidationError)
    @t.address.should eql('100d::fff0')
    @t.version.should eql(Yabitz::Model::IPAddress::IPv6)
  end

  it "にhostのリストとして空リストおよびnilが入力可能なこと" do 
    lambda {@t.hosts_by_id = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts_by_id.should eql([])
    lambda {@t.hosts_by_id = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts_by_id.should eql([])
    lambda {@t.hosts = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts.should eql([])
    lambda {@t.hosts = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts.should eql([])
  end

  it "にhostのリストがidで入出力可能なこと" do 
    lambda {@t.hosts_by_id = [1,2,3,4]}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts_by_id.should eql([1,2,3,4])
  end

  it "に #holder が正常に入出力可能なこと、またデフォルトがfalseであること" do
    @t.holder.should be_false
    lambda {@t.holder = true}.should_not raise_exception(Stratum::FieldValidationError)
    @t.holder.should be_true
    lambda {@t.holder = false}.should_not raise_exception(Stratum::FieldValidationError)
    @t.holder.should be_false
  end
  
  it "に #notes が正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.notes = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('')
    lambda {@t.notes = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('')

    lambda {@t.notes = 'hogepos'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('hogepos')
    lambda {@t.notes = "ほげぽす"}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql("ほげぽす")

    lambda {@t.notes = "0123456789"*102 + '0123'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.notes = "0123456789"*102 + '01234'}.should raise_exception(Stratum::FieldValidationError)
  end
end

describe Yabitz::Model::IPSegment do 
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end

  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  before do
    @cls = Yabitz::Model::IPSegment
    @t = @cls.new
  end

  it "にネットワークアドレスが正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.address = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.address = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.address = ' '}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.address = '192.168.0.1'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.address.should eql('192.168.0.1')
  end

  it "にネットマスクが正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.netmask = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.netmask = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.netmask = -1}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.netmask = '-1'}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.netmask = 100}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.netmask = 5}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.netmask = '24'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.netmask = '0'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.netmask = '64'}.should_not raise_exception(Stratum::FieldValidationError)
  end

  it "に #version が正常に入出力可能なこと、またv4/v6以外のものが入れられないこと" do 
    lambda {@t.version = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.version = ""}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.version = "4"}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.version = Yabitz::Model::IPAddress::IPv4}.should_not raise_exception(Stratum::FieldValidationError)
    @t.version.should eql(Yabitz::Model::IPAddress::IPv4)
    lambda {@t.version = Yabitz::Model::IPAddress::IPv6}.should_not raise_exception(Stratum::FieldValidationError)
    @t.version.should eql(Yabitz::Model::IPAddress::IPv6)
  end

  it "に #set を用いてネットワークアドレスおよびネットマスクが正常に入力可能なこと、また #version が同時に正しくセットされること" do
    lambda {@t.set('', '')}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.set('192.168.10.10', '')}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.set('', '8')}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.set('10.0.0.0', '8')}.should_not raise_exception(Stratum::FieldValidationError)
    @t.address.should eql('10.0.0.0')
    @t.version.should eql(Yabitz::Model::IPAddress::IPv4)
    @t.netmask.should eql('8')
    lambda {@t.set('100d::fff0', '32')}.should_not raise_exception(Stratum::FieldValidationError)
    @t.address.should eql('100d::fff0')
    @t.version.should eql(Yabitz::Model::IPAddress::IPv6)
    @t.netmask.should eql('32')
  end

  it "に #area としてlocal/globalがセット可能なこと、またそれ以外のものが入れられないこと" do
    lambda {@t.area = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.area = ""}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.area = "area hoge"}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.area = Yabitz::Model::IPSegment::AREA_LOCAL}.should_not raise_exception(Stratum::FieldValidationError)
    @t.area.should eql(Yabitz::Model::IPSegment::AREA_LOCAL)
    lambda {@t.area = Yabitz::Model::IPSegment::AREA_GLOBAL}.should_not raise_exception(Stratum::FieldValidationError)
    @t.area.should eql(Yabitz::Model::IPSegment::AREA_GLOBAL)
    
  end

  it "の初期状態で #ongoing が true であること、また変更可能なこと" do
    @t.ongoing?.should be_true
    lambda {@t.ongoing = true}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.ongoing = false}.should_not raise_exception(Stratum::FieldValidationError)
    @t.ongoing?.should be_false
  end

  it "に #notes が正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.notes = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('')
    lambda {@t.notes = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('')

    lambda {@t.notes = 'hogepos'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('hogepos')
    lambda {@t.notes = "ほげぽす"}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql("ほげぽす")

    lambda {@t.notes = "0123456789"*102 + '0123'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.notes = "0123456789"*102 + '01234'}.should raise_exception(Stratum::FieldValidationError)
  end
end

describe Yabitz::Model::RackUnit do 
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end

  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  before do
    @cls = Yabitz::Model::RackUnit
    @t = @cls.new
  end

  it "にrackunitが正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    # rackunit の形式チェックはプラグインに移譲するので正常チェックが不可能となった
    lambda {@t.rackunit = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.rackunit = nil}.should raise_exception(Stratum::FieldValidationError)
    # lambda {@t.rackunit = 'hoge-pos'}.should raise_exception(Stratum::FieldValidationError)

    # lambda {@t.rackunit = '5b-c05-b5'}.should_not raise_exception(Stratum::FieldValidationError)
    # @t.rackunit.should eql('5b-c05-b5')
    # lambda {@t.rackunit = '7x-p11-b2f'}.should_not raise_exception(Stratum::FieldValidationError)
    # @t.rackunit.should eql('7x-p11-b2f')
    # lambda {@t.rackunit = '7p-p11-b2r'}.should_not raise_exception(Stratum::FieldValidationError)
    # @t.rackunit.should eql('7p-p11-b2r')

    # lambda {@t.rackunit = '7p-p11-b2a'}.should raise_exception(Stratum::FieldValidationError)
  end
  
  it "に #dividing が正常に入出力可能なこと、またFULL/FRONT/REAR以外のものが入れられないこと、デフォルトがFULLであること" do
    @t.dividing.should eql(Yabitz::RackTypes::DIVIDING_FULL)
    lambda {@t.dividing = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.dividing = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.dividing = 'hoge'}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.dividing = Yabitz::RackTypes::DIVIDING_FULL}.should_not raise_exception(Stratum::FieldValidationError)
    @t.dividing.should eql(Yabitz::RackTypes::DIVIDING_FULL)
    lambda {@t.dividing = Yabitz::RackTypes::DIVIDING_HALF_FRONT}.should_not raise_exception(Stratum::FieldValidationError)
    @t.dividing.should eql(Yabitz::RackTypes::DIVIDING_HALF_FRONT)
    lambda {@t.dividing = Yabitz::RackTypes::DIVIDING_HALF_REAR}.should_not raise_exception(Stratum::FieldValidationError)
    @t.dividing.should eql(Yabitz::RackTypes::DIVIDING_HALF_REAR)
  end
  
  it "に rack が正常に入出力可能なこと" do
    lambda {@t.rack_by_id = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.rack = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.rack_by_id = 1}.should_not raise_exception(Stratum::FieldValidationError)
    @t.rack_by_id.should eql(1)
  end

  it "にhostのリストとして空リストおよびnilが入力可能なこと" do 
    lambda {@t.hosts_by_id = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts_by_id.should eql([])
    lambda {@t.hosts_by_id = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts_by_id.should eql([])
    lambda {@t.hosts = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts.should eql([])
    lambda {@t.hosts = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts.should eql([])
  end

  it "にhostのリストがidで入出力可能なこと" do 
    lambda {@t.hosts_by_id = [1,2,3,4]}.should_not raise_exception(Stratum::FieldValidationError)
    @t.hosts_by_id.should eql([1,2,3,4])
  end

  it "に #holder が正常に入出力可能なこと、またデフォルトがfalseであること" do
    @t.holder.should be_false
    lambda {@t.holder = true}.should_not raise_exception(Stratum::FieldValidationError)
    @t.holder.should be_true
    lambda {@t.holder = false}.should_not raise_exception(Stratum::FieldValidationError)
    @t.holder.should be_false
  end
  
  it "に #memo が正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.notes = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('')
    lambda {@t.notes = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('')

    lambda {@t.notes = 'hogepos'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('hogepos')
    lambda {@t.notes = "ほげぽす"}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql("ほげぽす")

    lambda {@t.notes = "0123456789"*102 + '0123'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.notes = "0123456789"*102 + '01234'}.should raise_exception(Stratum::FieldValidationError)
  end
end

describe Yabitz::Model::Rack do
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end

  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  before do
    @cls = Yabitz::Model::Rack
    @t = @cls.new
  end

  it "にラベルが正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.label = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.label = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.label = 'hoge-pos'}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.label = '5a-c05'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.label.should eql('5a-c05')
    lambda {@t.label = '7b-p01'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.label.should eql('7b-p01')
  end
  
  # プラグインに移譲したためテスト無効
  # it "に #type として DH_1 がセット可能なこと、デフォルトが DH_1 であること" do
  #   @t.type.should eql(@cls::RACKTYPE_DH_1)
  #   lambda {@t.type = ''}.should raise_exception(Stratum::FieldValidationError)
  #   lambda {@t.type = nil}.should raise_exception(Stratum::FieldValidationError)
  #   lambda {@t.type = 'TEKITO-'}.should raise_exception(Stratum::FieldValidationError)

  #   lambda {@t.type = @cls::RACKTYPE_DH_1}.should_not raise_exception(Stratum::FieldValidationError)
  #   @t.type.should eql(@cls::RACKTYPE_DH_1)
  # end
  
  # it "に #datacenter として DATAHOTEL がセット可能なこと、デフォルトが DATAHOTEL であること" do
  #   @t.datacenter.should eql(@cls::DC_DATAHOTEL)
  #   lambda {@t.datacenter = ''}.should raise_exception(Stratum::FieldValidationError)
  #   lambda {@t.datacenter = nil}.should raise_exception(Stratum::FieldValidationError)
  #   lambda {@t.datacenter = 'DATA CENTER 2'}.should raise_exception(Stratum::FieldValidationError)

  #   lambda {@t.datacenter = @cls::DC_DATAHOTEL}.should_not raise_exception(Stratum::FieldValidationError)
  #   @t.datacenter.should eql(@cls::DC_DATAHOTEL)
  # end

  it "の初期状態で #ongoing が true であること、また変更可能なこと" do
    @t.ongoing?.should be_true
    lambda {@t.ongoing = true}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.ongoing = false}.should_not raise_exception(Stratum::FieldValidationError)
    @t.ongoing?.should be_false
  end
  
  it "に #notes が正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.notes = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('')
    lambda {@t.notes = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('')

    lambda {@t.notes = 'hogepos'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('hogepos')
    lambda {@t.notes = "ほげぽす"}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql("ほげぽす")

    lambda {@t.notes = "0123456789"*102 + '0123'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.notes = "0123456789"*102 + '01234'}.should raise_exception(Stratum::FieldValidationError)
  end
end
