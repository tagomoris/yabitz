# -*- coding: utf-8 -*-

$YABITZ_RUN_ON_TEST_ENVIRONMENT = true

pwd = File.expand_path(File.dirname(__FILE__))

describe "Sinatraにおける初期化処理時" do
  before do 
  end

  after do
  end

  it "に Stratum が正常に読み込まれること" do
    load pwd + '/../../lib/yabitz/misc/init.rb'
    lambda {Stratum ; Stratum::Model ; Stratum::Connection}.should_not raise_exception(NameError)
  end

  it "にDBに接続するための情報が読み込まれること" do
    load pwd + '/../../lib/yabitz/misc/init.rb'
    conf = Yabitz.config()
    conf.should be_instance_of(Yabitz::Config::Base)
    conf.dbparams[3].should eql('yabitztest')
  end
  
  it "に Stratum::Connection.setup() が行われ、dev-DBへのコネクションがとれること" do
    load pwd + '/../../lib/yabitz/misc/init.rb'
    load pwd + '/../../scripts/db_schema.rb'

    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())

    Stratum::Connection.setupped?.should be_true
    Stratum.conn do |c|
      c.should_not be_nil
      c.ping().should be_true
    end

    Yabitz::Schema.teardown_test_db()
  end
  
  it "に Stratum に正常にオペレータのモデルがセットされ、dev-DBのrootユーザがとれること" do
    load pwd + '/../../lib/yabitz/misc/init.rb'
    load pwd + '/../../scripts/db_schema.rb'

    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())

    root = Stratum.operator_model.get_root()
    root.should_not be_nil
    root.should be_kind_of(Stratum::Model)

    Yabitz::Schema.teardown_test_db()
  end
end
