# -*- coding: utf-8 -*-

$YABITZ_RUN_ON_TEST_ENVIRONMENT = true

require_relative '../lib/yabitz/misc/init'
require_relative '../scripts/db_schema'
require_relative '../lib/yabitz/model/informations'

describe Yabitz::Model::HwInformation do 
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end

  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  before do
    @cls = Yabitz::Model::HwInformation
    @t = @cls.new
  end

  it "の .normalize_units が正常に全角半角変換、および小文字大文字変換を行うこと" do
    @cls.normalize_units('').should eql('')
    @cls.normalize_units(nil).should be_nil
    @cls.normalize_units('1').should eql('1U')
    @cls.normalize_units('1U').should eql('1U')
    @cls.normalize_units('1u').should eql('1U')
    @cls.normalize_units('15U').should eql('15U')
    @cls.normalize_units('15Ｕ').should eql('15U')
    @cls.normalize_units('１５ｕ').should eql('15U')
    @cls.normalize_units('FULL').should eql('FULL')
    @cls.normalize_units('Full').should eql('FULL')
    @cls.normalize_units('half').should eql('HALF')
    @cls.normalize_units('1/4').should eql('1/4')
    @cls.normalize_units('（ｈａｌｆ）').should eql('(HALF)')
    @cls.normalize_units('　（１／４）').should eql('(1/4)')
    @cls.normalize_units('2u (Half)').should eql('2U(HALF)')
    @cls.normalize_units('2uHalf').should eql('2U(HALF)')
    @cls.normalize_units('129U （ＦＵＬＬ）').should eql('129U(FULL)')
    @cls.normalize_units('２Ｕ　（Ｈａｌｆ） ').should eql('2U(HALF)')
  end

  it "に #name が正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.name = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = 'a'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = 'ほげ'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.name.should eql('ほげ')
    lambda {@t.name = 'AM3 2'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.name.should eql('AM3 2')
  end

  it "に #prior が正常に入出力可能なこと、またデフォルトがfalseであること" do
    @t.prior.should be_false
    @t.prior = true
    @t.prior.should be_true
  end

  it "に #units が正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.units = ''}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.units = nil}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.units = '1U'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.units.should eql('1U')
    lambda {@t.units = '1u'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.units = '15U'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.units.should eql('15U')
    lambda {@t.units = '１５Ｕ'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.units = '1U(FULL)'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.units.should eql('1U(FULL)')
    lambda {@t.units = '1U(full)'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.units = '1U(HALF)'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.units.should eql('1U(HALF)')
    lambda {@t.units = '1U(half)'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.units = '１ｕ（ｆｕｌｌ）'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.units.should eql('1U(FULL)')
    lambda {@t.units = '1U(Full)'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.units.should eql('1U(FULL)')
    lambda {@t.units = '1U (FULL)'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.units = '１ｕ （ｆｕｌｌ）'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.units = ' １ｕ（ｆｕｌｌ）　'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.units.should eql('1U(FULL)')
    
    lambda {@t.units = '1U(1/4)'}.should raise_exception(Stratum::FieldValidationError)
  end

  it "に #calcunits が正常に入出力可能なこと、またvalidatorのチェックを通っていること" do
    lambda {@t.calcunits = ''}.should_not raise_exception(Stratum::FieldValidationError)
    @t.calcunits.should eql('')
    lambda {@t.calcunits = nil}.should_not raise_exception(Stratum::FieldValidationError)
    @t.calcunits.should eql('')

    lambda {@t.calcunits = 4.2}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.calcunits = '100'}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.calcunits = '50.001'}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.calcunits = '4.2'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.calcunits.should eql('4.2')
    @t.calcunits.to_f.should eql(4.2)
    lambda {@t.calcunits = '12'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.calcunits.should eql('12')
    @t.calcunits.to_f.should eql(12.0)
    lambda {@t.calcunits = '1.0'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.calcunits.should eql('1.0')
    @t.calcunits.to_f.should eql(1.0)
    lambda {@t.calcunits = '15.25'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.calcunits.should eql('15.25')
    @t.calcunits.to_f.should eql(15.25)
  end

  it "に #virtualized が正常に入出力可能なこと、またデフォルトが false であること" do
    @t.virtualized.should be_false
    @t.virtualized?.should be_false

    lambda {@t.virtualized = true}.should_not raise_exception(Stratum::FieldValidationError)
    @t.virtualized?.should be_true
    lambda {@t.virtualized = false}.should_not raise_exception(Stratum::FieldValidationError)
    @t.virtualized?.should be_false
  end

  it "に #units_calculated すると #units に応じて適切な数値の文字列表現が返ること" do
    @t.units = "1"
    @t.units.should eql("1U")
    @t.units_calculated.should eql("1")

    @t.units = "3u"
    @t.units.should eql("3U")
    @t.units_calculated.should eql("3")
    @t.units = "2U(full)"
    @t.units.should eql("2U(FULL)")
    @t.units_calculated.should eql("2")

    @t.units = "2U(HALF)"
    @t.units.should eql("2U(HALF)")
    @t.units_calculated.should eql("1")
    
    @t.units = "1U(HALF)"
    @t.units.should eql("1U(HALF)")
    @t.units_calculated.should eql("0.5")
    
    @t.units = "2U(HALF)"
    @t.units.should eql("2U(HALF)")
    @t.units_calculated.should eql("1")
  end

end

describe Yabitz::Model::OSInformation do
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end

  before do
    @cls = Yabitz::Model::OSInformation
    @t = @cls.new
  end

  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  it "の .normalize_name が正常に全角半角変換、および小文字大文字変換と前後スペースの削除を行うこと" do
    @cls.normalize_name('').should eql('')
    @cls.normalize_name(nil).should eql(nil)
    @cls.normalize_name('CentOS5').should eql('CentOS5')
    @cls.normalize_name(' CentOS 5.2 (64bit) ').should eql('CentOS 5.2 (64bit)')
    @cls.normalize_name('WindowsServer 2003 ').should eql('WindowsServer 2003')
    @cls.normalize_name('Debian GNU/Linux').should eql('Debian GNU/Linux')
    @cls.normalize_name('ＣｅｎｔＯＳ　５．２').should eql('CentOS 5.2')
    @cls.normalize_name('ＣｅｎｔＯＳ　５．２（３２ｂｉｔ）').should eql('CentOS 5.2(32bit)')
    @cls.normalize_name('Ｄｅｂｉａｎ　ＧＮＵ／Ｌｉｎｕｘ　').should eql('Debian GNU/Linux')
  end
  
  it "で #name が正常に入出力可能なこと" do
    lambda {@t.name = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = 'a'*65}.should raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = 'a'*64}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = 'CentOS5'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {@t.name = 'CentOS5(64bit)'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.name.should eql('CentOS5(64bit)')
    lambda {@t.name = 'CentOS 5.2 '}.should_not raise_exception(Stratum::FieldValidationError)
    @t.name.should eql('CentOS 5.2')
    lambda {@t.name = 'CentOS 5.2 (64bit)'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.name.should eql('CentOS 5.2 (64bit)')
    lambda {@t.name = 'CentOS 5.2 (64bit)'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.name.should eql('CentOS 5.2 (64bit)')
    lambda {@t.name = 'ＣｅｎｔＯＳ５．２'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.name.should eql('CentOS5.2')
    lambda {@t.name = 'ＣｅｎｔＯＳ　５．２'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.name.should eql('CentOS 5.2')
    lambda {@t.name = 'ＣｅｎｔＯＳ５．２（６４ｂｉｔ）'}.should_not raise_exception(Stratum::FieldValidationError)
    @t.name.should eql('CentOS5.2(64bit)')
  end

  it "に #prior が正常に入出力可能なこと、またデフォルトがfalseであること" do
    @t.prior.should be_false
    @t.prior = true
    @t.prior.should be_true
  end

  it "の .all で、保存済みオブジェクトのリストが名前を辞書順に並べた形で取れること" do
    @cls.query_or_create(:name => "CentOS5")
    @cls.query_or_create(:name => "CentOS6")
    @cls.query_or_create(:name => "CentOS5.1")
    @cls.query_or_create(:name => "CentOS5.0")
    @cls.query_or_create(:name => "RedHatEL5.4")
    @cls.query_or_create(:name => "RHEL6")
    @cls.query_or_create(:name => "Debian5.0")
    @cls.query_or_create(:name => "Ubuntu10.04")
    @cls.query_or_create(:name => "FreeBSD7.0")
    @cls.query_or_create(:name => "Turbo10")
    @cls.query_or_create(:name => "WindowsServer2003")
    @cls.query_or_create(:name => "network")
    @cls.query_or_create(:name => "CentOS5(64bit)")
    @cls.query_or_create(:name => "CentOS5(32bit)")

    @cls.all(:sorted => true).map{|os| os.name}.should eql(['CentOS5', 'CentOS5(32bit)', 'CentOS5(64bit)', 'CentOS5.0', 'CentOS5.1', 'CentOS6',
                                               'Debian5.0', 'FreeBSD7.0', 'RHEL6', 'RedHatEL5.4', 'Turbo10', 'Ubuntu10.04', 'WindowsServer2003',
                                               'network'])
  end
end
