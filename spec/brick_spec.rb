# -*- coding: utf-8 -*-

$YABITZ_RUN_ON_TEST_ENVIRONMENT = true

require_relative '../lib/yabitz/misc/init'
require_relative '../scripts/db_schema'
require_relative '../lib/yabitz/model/brick'

describe Yabitz::Model::Brick do
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end

  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  before do
    @cls = Yabitz::Model::Brick
    @t = @cls.new
  end

  it "の normalizer が正常に納品日の形式訂正を行うこと" do
    @cls.normalize_delivered(nil).should eql(nil)
    @cls.normalize_delivered('').should eql('')

    @cls.normalize_delivered('2011-07-01').should eql('2011-07-01')

    @cls.normalize_delivered('２０１１／７／１').should eql('2011-07-01')
    @cls.normalize_delivered('２０１１／０７／１').should eql('2011-07-01')
    @cls.normalize_delivered('２０１１０７０１').should eql('2011-07-01')
    @cls.normalize_delivered('２０１１−７−１').should eql('2011-07-01')
    @cls.normalize_delivered('２０１１．７．１').should eql('2011-07-01')
    @cls.normalize_delivered('２０１１　０７　０１').should eql('2011-07-01')

    @cls.normalize_delivered('20110701').should eql('2011-07-01')
    @cls.normalize_delivered('2011/07/01').should eql('2011-07-01')
    @cls.normalize_delivered('2011/7/1').should eql('2011-07-01')
    @cls.normalize_delivered('2011 07 01').should eql('2011-07-01')
    @cls.normalize_delivered('2011.07.01').should eql('2011-07-01')
  end

  it "の validator が正常に納品日の形式チェックを行うこと" do
    @t.check_delivered(nil).should be_false
    @t.check_delivered('').should be_false

    @t.check_delivered('2011-07-01').should be_true
    @t.check_delivered('2011-07-31').should be_true
    @t.check_delivered('2011-07-32').should be_false
    @t.check_delivered('2011-13-01').should be_false
  end

  it "の #hwid が空欄を許さず、また16文字以下の文字列のみを受け入れること" do
    
  end

  it "の #productname が空欄を許さず、また64文字以下の文字列のみを受け付けること" do
    lambda {@t.productname = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.productname = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.productname = 'a' * 65}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.productname = 'a'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.productname = 'a' * 64}.should_not raise_exception(Stratum::FieldValidationError)
  end

  it "の #delivered が日付として正常のもののみを受け付けること" do
    lambda {@t.delivered = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.delivered = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.delivered = '2011-07-01'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.delivered = '2011-06-30'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.delivered = '2011-06-31'}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.delivered = '2011-02-29'}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.delivered = '2012-02-29'}.should_not raise_exception(Stratum::FieldValidationError)
  end

  it "の #status が STOCK/IN_USE/REPAIR/BROKEN のみを受け付けること" do
    lambda {@t.status = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.status = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.status = 'hoge'}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.status = Yabitz::Model::Brick::STATUS_STOCK}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.status = Yabitz::Model::Brick::STATUS_IN_USE}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.status = Yabitz::Model::Brick::STATUS_REPAIR}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.status = Yabitz::Model::Brick::STATUS_BROKEN}.should_not raise_exception(Stratum::FieldValidationError)
  end

  it "の #status のデフォルトが STOCK であること" do
    @cls.new.status.should eql(Yabitz::Model::Brick::STATUS_STOCK)
  end

  it "の #<=> が status(stock->repair->broken->in_use?) -> hwid の順にソート対象とすること" do
    t1 = @cls.new; t1.serial = 't1'; t1.status = Yabitz::Model::Brick::STATUS_STOCK
    t2 = @cls.new; t2.serial = 't2'; t2.status = Yabitz::Model::Brick::STATUS_REPAIR
    t3 = @cls.new; t3.serial = 't3'; t3.status = Yabitz::Model::Brick::STATUS_BROKEN
    t4 = @cls.new; t4.serial = 't4'; t4.status = Yabitz::Model::Brick::STATUS_IN_USE
    [t2, t4, t3, t1].sort.map(&:serial).should eql(['t1', 't2', 't3', 't4'])

    # default status is 'STOCK'
    ta = @cls.new; ta.serial = 'ta'; ta.status = Yabitz::Model::Brick::STATUS_STOCK; ta.hwid = 'XX1'; ta.productname = 'B11'; ta.delivered = '2011-07-02'
    tb = @cls.new; tb.serial = 'tb'; tb.status = Yabitz::Model::Brick::STATUS_STOCK; tb.hwid = 'XX2'; tb.productname = 'A9'; tb.delivered = '2011-07-07'
    tc = @cls.new; tc.serial = 'tc'; tc.status = Yabitz::Model::Brick::STATUS_STOCK; tc.hwid = 'XX21'; tc.productname = 'A2'; tc.delivered = '2011-07-03'
    td = @cls.new; td.serial = 'td'; td.status = Yabitz::Model::Brick::STATUS_REPAIR; td.hwid = 'XA1'; td.productname = 'B1'; td.delivered = '2011-07-01'
    te = @cls.new; te.serial = 'te'; te.status = Yabitz::Model::Brick::STATUS_REPAIR; te.hwid = 'XX1'; te.productname = 'A3'; te.delivered = '2011-06-01'
    tf = @cls.new; tf.serial = 'tf'; tf.status = Yabitz::Model::Brick::STATUS_BROKEN; tf.hwid = 'X'; tf.productname = 'XX1'; tf.delivered = '2011-07-11'
    tg = @cls.new; tg.serial = 'tg'; tg.status = Yabitz::Model::Brick::STATUS_BROKEN; tg.hwid = 'XX1'; tg.productname = 'B1'; tg.delivered = '2011-07-09'
    th = @cls.new; th.serial = 'th'; th.status = Yabitz::Model::Brick::STATUS_IN_USE; th.hwid = 'AX1'; th.productname = 'B11'; th.delivered = '2011-07-01'
    ti = @cls.new; ti.serial = 'ti'; ti.status = Yabitz::Model::Brick::STATUS_IN_USE; ti.hwid = 'XX1'; ti.productname = 'A0'; ti.delivered = '2011-07-06'
    [th, ti, td, ta, tb, tf, tg, tc, te].sort.map(&:serial).should eql(['ta', 'tb', 'tc', 'td', 'te', 'tf', 'tg', 'th', 'ti'])
  end

  it "の .build_raw_csv が正常に内部データのCSV表現を返すこと" do
    t1 = @cls.query_or_create(:status => Yabitz::Model::Brick::STATUS_STOCK, :productname => 'RX100', :delivered => '2011-07-01', :serial => '00001-XXX1-F1')
    t2 = @cls.query_or_create(:status => Yabitz::Model::Brick::STATUS_IN_USE, :productname => 'RX100 "xxx"', :delivered => '2011-07-01', :serial => '00001-XXX1-F1')
    t3 = @cls.query_or_create(:status => Yabitz::Model::Brick::STATUS_IN_USE, :productname => 'MacBookAir, early 2011', :delivered => '2011/07/01', :serial => '00002 ZZZZ 0X')

    # CSVFIELDS = [:oid, :productname, :delivered, :status, :serial]
    header = "OID,PRODUCTNAME,DELIVERED,STATUS,SERIAL\n"
    @cls.build_raw_csv(Yabitz::Model::Brick::CSVFIELDS, [t1]).should eql(header + t1.oid.to_s + ',RX100,2011-07-01,STOCK,00001-XXX1-F1' + "\n")
    @cls.build_raw_csv(Yabitz::Model::Brick::CSVFIELDS, [t2]).should eql(header + t2.oid.to_s + ',"RX100 ""xxx""",2011-07-01,IN_USE,00001-XXX1-F1' + "\n")
    @cls.build_raw_csv(Yabitz::Model::Brick::CSVFIELDS, [t3]).should eql(header + t3.oid.to_s + ',"MacBookAir, early 2011",2011-07-01,IN_USE,00002 ZZZZ 0X' + "\n")
  end
end
