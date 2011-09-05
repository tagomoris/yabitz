# -*- coding: utf-8 -*-

$YABITZ_RUN_ON_TEST_ENVIRONMENT = true

require_relative '../lib/yabitz/misc/init'
require_relative '../scripts/db_schema'
require_relative '../lib/yabitz/model/company'

describe Yabitz::Model::Dept do
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end
  
  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  before do
    @cls = Yabitz::Model::Dept
    @t = @cls.new
  end

  it "に #name を正常にセットできること" do
    t = Yabitz::Model::Dept.new

    lambda {t.name = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {t.name = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {t.name = 'a'*65}.should raise_exception(Stratum::FieldValidationError)
    lambda {t.name = 'a'*64}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {t.name = 'hoge Service'}.should_not raise_exception(Stratum::FieldValidationError)
    t.name.should eql('hoge Service')
    lambda {t.name = 'ポータル'}.should_not raise_exception(Stratum::FieldValidationError)
    t.name.should eql('ポータル')
  end

  it "に .all を行うことで、正常に全件取得可能で :name フィールドによりソートされていること" do
    ["hoge", "pos", "tago", "ace", "bascas", "bosco", "zabas", "zavas", "savas"].each do |n|
      i = @cls.new
      i.name = n
      i.save
    end
    @cls.all(:sorted => true).map(&:name).should eql(["ace", "bascas", "bosco", "hoge", "pos", "savas", "tago", "zabas", "zavas"])
  end
end

describe Yabitz::Model::Content do
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end
  
  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  before do
    @cls = Yabitz::Model::Content
    @t = @cls.new
  end

  it "に #name を正常にセットできること" do
    lambda {@t.name = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = 'blog'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.name.should eql('blog')
    lambda {@t.name = 'blog new'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.name.should eql('blog new')
    lambda {@t.name = 'ぶろぐにゅー'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.name.should eql('ぶろぐにゅー')
    lambda {@t.name = 'a'*64}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = 'a'*65}.should raise_exception(Stratum::FieldValidationError)
  end
  
  it "に #charging がデフォルトで nil であり nil, 空文字もしくは CHARGING_LABELS のうちの値をセットできること" do
    @t.charging.should be_nil
    lambda {@t.charging = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.charging.should eql('')
    lambda {@t.charging = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.charging.should eql('')
    lambda {@t.charging = @cls::CHARGING_NO_COUNT}.should_not raise_exception(Stratum::FieldValidationError)
    @t.charging.should eql(@cls::CHARGING_NO_COUNT)
    lambda {@t.charging = @cls::CHARGING_SHARED}.should_not raise_exception(Stratum::FieldValidationError)
    @t.charging.should eql(@cls::CHARGING_SHARED)
  end

  it "に #code を正常にセットできること" do
    lambda {@t.code = ''}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.code = nil}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.code = 'a'*17}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.code = 'a'*16}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.code = '201'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.code.should eql('201')
    lambda {@t.code = '123'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.code.should eql('123')
    lambda {@t.code = '54'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.code.should eql('54')
  end
  
  it "において has_code? は code が nil や空文字、'NONE' 以外の場合に true を返すこと" do
    @t.code = nil
    @t.has_code?.should be_false
    @t.code = ''
    @t.has_code?.should be_false
    @t.code = 'NONE'
    @t.has_code?.should be_false

    @t.code = '256'
    @t.has_code?.should be_true
  end

  it "に #dept を id もしくはオブジェクトで正常にセットできること" do
    lambda {@t.dept_by_id = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.dept = nil}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.dept_by_id = 32}.should_not raise_exception(Stratum::FieldValidationError)
    @t.dept_by_id.should eql(32)

    dept1 = Yabitz::Model::Dept.query_or_create(:name => 'MD')
    d_oid = dept1.oid

    @t.dept = dept1
    @t.dept_by_id.should eql(d_oid)
    @t.dept.oid.should eql(d_oid)
    @t.dept.name.should eql('MD')
  end
  
  it "に #services を id のリストとして正常にセットできること" do
    lambda {@t.services_by_id = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.services_by_id.should eql([])
    @t.services.should eql([])
    lambda {@t.services_by_id = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.services_by_id.should eql([])
    @t.services.should eql([])

    lambda {@t.services = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.services_by_id.should eql([])
    @t.services.should eql([])
    lambda {@t.services = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.services_by_id.should eql([])
    @t.services.should eql([])

    lambda {@t.services_by_id = [5,7,120,2]}.should_not raise_exception(Stratum::FieldValidationError)
    @t.services_by_id.should eql([5,7,120,2])
  end

  it "に .all を行うことで、正常に全件取得可能で :name フィールドによりソートされていること" do 
    Stratum.conn do |c|
      c.query("DELETE FROM #{@cls.tablename}")
    end
    ["hoge", "pos", "tago", "ace", "bascas", "bosco", "zabas", "zavas", "savas"].each do |n|
      i = @cls.new
      i.name = n
      i.save
    end
    i2 = @cls.new
    i2.name = "zzz"
    i2.save
    i2.remove
    @cls.all(:sorted => true).map(&:name).should eql(["ace", "bascas", "bosco", "hoge", "pos", "savas", "tago", "zabas", "zavas"])
  end
end

describe Yabitz::Model::Service do
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end
  
  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  before do
    @cls = Yabitz::Model::Service
    @t = @cls.new
  end

  it "に #name を正常にセットできること" do
    lambda {@t.name = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = 'a'*65}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = 'あ'*65}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.name = 'a'*64}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = 'あ'*64}.should_not raise_exception(Stratum::FieldValidationError)

    lambda {@t.name = 'hoge'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.name.should eql('hoge')
    lambda {@t.name = 'あいうえ'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.name.should eql('あいうえ')
  end
  
  it "に #mladdress を正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.mladdress = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.mladdress.should eql('')
    lambda {@t.mladdress = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.mladdress.should eql('')
    
    lambda {@t.mladdress = 'hoge @ pos.com'}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.mladdress = 'hoge-ld-dev@livedoor.jp'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.mladdress.should eql('hoge-ld-dev@livedoor.jp')
  end
  
  it "に #urls を id によって正常に入出力可能なこと" do
    @t.urls_by_id.should eql([])
    @t.urls.should eql([])
    @t.urls = nil
    @t.urls.should eql([])
    @t.urls = []
    @t.urls.should eql([])

    @t.urls_by_id = [5, 100, 10000]
    @t.urls_by_id.should eql([5, 100, 10000])
  end

  it "に #contact を id によって正常に入出力可能なこと" do
    @t.contact_by_id.should be_nil
    @t.contact.should be_nil
    @t.contact = nil
    @t.contact.should be_nil

    @t.contact_by_id = 10
    @t.contact_by_id.should eql(10)
  end

  it "に #notes を正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.notes = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('')
    lambda {@t.notes = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.notes.should eql('')

    @t.notes = "hoge moge pos\nHAHAHAHA ok."
    @t.notes.should eql("hoge moge pos\nHAHAHAHA ok.")

    lambda {@t.notes = "a"*4096}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.notes = "a"*4097}.should raise_exception(Stratum::FieldValidationError)
  end

  it "に #content を id で正常にセットできること" do
    lambda {@t.content = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.content_by_id = nil}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.content_by_id = 30}.should_not raise_exception(Stratum::FieldValidationError)
    @t.content_by_id.should eql(30)
  end

  it "に .all を行うことで、正常に全件取得可能で :name フィールドによりソートされていること" do 
    Stratum.conn do |c|
      c.query("DELETE FROM #{@cls.tablename}")
    end
    ["hoge", "pos", "tago", "ace", "bascas", "bosco", "zabas", "zavas", "savas"].each do |n|
      i = @cls.new
      i.name = n
      i.save
    end
    i2 = @cls.new
    i2.name = "zzz"
    i2.save
    i2.remove
    @cls.all(:sorted => true).map(&:name).should eql(["ace", "bascas", "bosco", "hoge", "pos", "savas", "tago", "zabas", "zavas"])
  end
end
