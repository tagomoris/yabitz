# -*- coding: utf-8 -*-

$YABITZ_RUN_ON_TEST_ENVIRONMENT = true

require_relative '../lib/yabitz/misc/init'
require_relative '../scripts/db_schema'
require_relative '../lib/yabitz/model/host_misc'
require_relative '../lib/yabitz/model/host'

describe Yabitz::Model::TagChain do
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end

  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end
  
  before do
    @cls = Yabitz::Model::TagChain
    @t = @cls.new
  end

  it "に #host をidで正常に入出力できること" do
    lambda {@t.host_by_id = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.host_by_id = 5}.should_not raise_exception(Stratum::FieldValidationError)
    @t.host_by_id.should eql(5)
  end
  
  it "に #tagchain として文字列のリストを正常に入出力できること、およびそのタグでクエリできること" do
    Stratum.conn do |c|
      c.query("SELECT count(*) FROM #{@cls.tablename}").fetch_row.first.should eql("0")
    end

    lambda {@t.tagchain = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.tagchain.should eql([])
    lambda {@t.tagchain = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.tagchain.should eql([])

    @t.host_by_id = 0
    @t.tagchain = ['ab', 'bc', 'cd,de', 'ef fg', '2010-09-01', 'posmoge']
    @t.tagchain.should eql(['ab', 'bc', 'cd,de', 'ef fg', '2010-09-01', 'posmoge'])
    @t.save

    @cls.query(:tagchain => 'ab').size.should eql(1)
    @cls.query(:tagchain => 'bc').size.should eql(1)
    @cls.query(:tagchain => 'cd,de').size.should eql(1)
    @cls.query(:tagchain => 'ef').size.should eql(1)
    @cls.query(:tagchain => 'fg').size.should eql(1)

    @cls.query(:tagchain => 'hoge').size.should eql(0)

    @cls.query(:tagchain => '2010-09-01').size.should eql(1)

    @cls.query(:tagchain => 'moge').size.should eql(0)

    t = @cls.new
    t.host_by_id = 0
    t.tagchain = ['Webサーバ', 'DB', 'memcache', '開発']
    t.save

    @cls.query(:tagchain => 'サーバ').size.should eql(0)
    @cls.query(:tagchain => 'memcache').size.should eql(1)
    @cls.query(:tagchain => 'DB').size.should eql(1)

    Stratum.conn do |c|
      c.query("DELETE FROM #{@cls.tablename}")
    end
  end
end

describe Yabitz::Model::ContactMember do 
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end

  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end
  
  before do
    @cls = Yabitz::Model::ContactMember
    @t = @cls.new
  end

  it "に #name を正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.name = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = 'a'*65}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = 'あ'*65}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.name = 'a'*64}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = 'あ'*64}.should_not raise_exception(Stratum::FieldValidationError)
  end
  
  it "に #telno を正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.telno = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.telno.should eql('')
    lambda {@t.telno = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.telno.should eql('')

    lambda {@t.telno = 'a'*65}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.telno = 'あ'*65}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.telno = 'a'*64}.should_not raise_exception(Stratum::FieldValidationError)
    @t.telno.should eql('a'*64)
    lambda {@t.telno = 'あ'*64}.should_not raise_exception(Stratum::FieldValidationError) 
    @t.telno.should eql('あ'*64)
  end
  
  it "に #mail を正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.mail = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.mail.should eql('')
    lambda {@t.mail = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.mail.should eql('')

    lambda {@t.mail = 'a@b.com'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.mail.should eql('a@b.com')

    lambda {@t.mail = 'a@b c.net'}.should raise_exception(Stratum::FieldValidationError)
  end
  
  it "に #comment を正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.comment = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.comment.should eql('')
    lambda {@t.comment = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.comment.should eql('')

    lambda {@t.comment = 'a'*4097}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.comment = 'あ'*4097}.should raise_exception(Stratum::FieldValidationError)
    
    lambda {@t.comment = 'a'*4096}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.comment = 'あ'*4096}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.comment = 'comment ほげほげ'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.comment.should eql('comment ほげほげ')
  end
end

describe Yabitz::Model::Contact do 
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end

  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end
  
  before do
    @cls = Yabitz::Model::Contact
    @t = @cls.new
  end

  it "に #label を正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.label = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.label = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.label = 'a'*65}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.label = 'あ'*65}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.label = 'a'*64}.should_not raise_exception(Stratum::FieldValidationError)
    @t.label.should eql('a'*64)
    lambda {@t.label = 'あ'*64}.should_not raise_exception(Stratum::FieldValidationError)
    @t.label.should eql('あ'*64)
  end
  
  it "に #memo を正常に入出力可能なこと、またvalidatorのチェックを通っていること" do 
    lambda {@t.memo = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.memo.should eql('')
    lambda {@t.memo = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.memo.should eql('')

    lambda {@t.memo = 'a'*4097}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.memo = 'あ'*4097}.should raise_exception(Stratum::FieldValidationError)
    
    lambda {@t.memo = 'a'*4096}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.memo = 'あ'*4096}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.memo = 'memo ほげほげ'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.memo.should eql('memo ほげほげ')
  end
  
  it "に #telno_daytime を正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.telno_daytime = ''}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.telno_daytime = nil}.should_not raise_exception(Stratum::FieldValidationError)

    lambda {@t.telno_daytime = 'a'*65}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.telno_daytime = 'あ'*65}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.telno_daytime = 'a'*64}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.telno_daytime = 'あ'*64}.should_not raise_exception(Stratum::FieldValidationError)

    lambda {@t.telno_daytime = '03-5155-0100'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.telno_daytime.should eql('03-5155-0100')
  end
  it "に #mail_daytime を正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.mail_daytime = ''}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.mail_daytime = nil}.should_not raise_exception(Stratum::FieldValidationError)

    lambda {@t.mail_daytime = 'a@b.com'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.mail_daytime.should eql('a@b.com')

    lambda {@t.mail_daytime = 'a@b c.net'}.should raise_exception(Stratum::FieldValidationError)
  end

  it "に #telno_offtime を正常に入出力可能なこと、またvalidatorのチェックを通っていること" do 
    lambda {@t.telno_offtime = ''}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.telno_offtime = nil}.should_not raise_exception(Stratum::FieldValidationError)

    lambda {@t.telno_offtime = 'a'*65}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.telno_offtime = 'あ'*65}.should raise_exception(Stratum::FieldValidationError)

    lambda {@t.telno_offtime = 'a'*64}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.telno_offtime = 'あ'*64}.should_not raise_exception(Stratum::FieldValidationError)

    lambda {@t.telno_offtime = '03-5155-0100'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.telno_offtime.should eql('03-5155-0100')
  end

  it "に #mail_offtime を正常に入出力可能なこと、またvalidatorのチェックを通っていること" do 
    lambda {@t.mail_offtime = ''}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.mail_offtime = nil}.should_not raise_exception(Stratum::FieldValidationError)

    lambda {@t.mail_offtime = 'a@b.com'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.mail_offtime.should eql('a@b.com')

    lambda {@t.mail_offtime = 'a@b c.net'}.should raise_exception(Stratum::FieldValidationError)
  end
  
  it "に #services をidで正常に入出力可能なこと" do
    lambda {@t.services_by_id = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.services.should eql([])
    lambda {@t.services_by_id = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.services.should eql([])
    lambda {@t.services = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.services.should eql([])
    lambda {@t.services = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.services.should eql([])

    lambda {@t.services_by_id = [1,2,3,4,10]}.should_not raise_exception(Stratum::FieldValidationError)
    @t.services_by_id.should eql([1,2,3,4,10])
  end

  it "に #members をidで正常に入出力可能なこと" do 
    lambda {@t.members_by_id = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.members.should eql([])
    lambda {@t.members_by_id = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.members.should eql([])
    lambda {@t.members = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.members.should eql([])
    lambda {@t.members = []}.should_not raise_exception(Stratum::FieldValidationError)
    @t.members.should eql([])

    lambda {@t.members_by_id = [1,2,3,4,10]}.should_not raise_exception(Stratum::FieldValidationError)
    @t.members_by_id.should eql([1,2,3,4,10])
  end
end
