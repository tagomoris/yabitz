# -*- coding: utf-8 -*-

$YABITZ_RUN_ON_TEST_ENVIRONMENT = true
require_relative '../lib/yabitz/misc/init'
require_relative '../scripts/db_schema'

describe Yabitz::Model::AuthInfo do
  before(:all) do
    Yabitz::Schema.setup_test_db()
    Stratum::ModelCache.flush()
    Stratum.current_operator(Yabitz::Model::AuthInfo.get_root())
  end

  before do
    @cls = Yabitz::Model::AuthInfo
    @root = @cls.get_root()
    @new_user = @cls.new()
  end

  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  it "から root が取得できること" do
    root = Yabitz::Model::AuthInfo.get_root()
    root.should_not be_nil
    root.name.should eql('root')
  end
  
  it "のインスタンスが admin かどうか判定できること、また admin 権限をセットできること" do
    @new_user.admin?.should be_false
    @new_user.set_admin
    @new_user.admin?.should be_true
    @new_user.priv.should eql(Yabitz::Model::AuthInfo::PRIV_ADMIN)
  end

  #### db_schema setup inserts batchmaker as ADMIN
  # it "が ADMIN 権限を持つユーザがいないことを正常に識別できること" do
  #   @cls.query(:priv => @cls::PRIV_ADMIN).size.should eql(0)
  #   @cls.has_administrator?.should be_false
  #   @new_user.name = "admin-kun"
  #   @new_user.fullname = "admin-kun-namae"
  #   @new_user.set_admin
  #   @new_user.save
  #   @cls.has_administrator?.should be_true
  # end

  # deplicated with LDAP implementation...
  # TODO fix authentication-provider as plugin, and make test rebuilded...

  # it "に、まだ存在しないusernameで認証を通したとき、新しいレコードが作成され、認証に成功すること" do
  #   Yabitz::Model::AuthInfo.query(:name => "hogepos").size.should eql(0)
  #   user = Yabitz::Model::AuthInfo.authenticate("hogepos", "dummypass")
  #   user.should_not be_nil
  #   user.name.should eql("hogepos")
  #   user.valid?.should be_true
  #   user.admin?.should be_false
  #   user.saved?.should be_true
  #   Yabitz::Model::AuthInfo.query(:name => "hogepos").size.should eql(1)
  # end
  
  # it "に、既に存在するusernameで認証を通したとき、認証に成功すること" do
  #   Yabitz::Model::AuthInfo.query(:name => "mogemoge").size.should eql(0)
  #   moge = Yabitz::Model::AuthInfo.new
  #   moge.name = "mogemoge"
  #   moge.fullname = "moge mogera"
  #   moge.save
  #   Yabitz::Model::AuthInfo.query(:name => "mogemoge").size.should eql(1)
  #   m = Yabitz::Model::AuthInfo.authenticate("mogemoge", "dummypass", "192.168.1.1")
  #   m.should_not be_nil
  #   m.name.should eql("mogemoge")
  #   m.fullname.should eql("moge mogera")
  #   m.valid?.should be_true
  #   m.admin?.should be_false
  #   Yabitz::Model::AuthInfo.query(:name => "mogemoge").size.should eql(1)
  # end
  
  it "に、存在するが valid? が false なusernameの場合、認証が通るはずでも失敗すること" do
    Yabitz::Model::AuthInfo.query(:name => "fuga").size.should eql(0)
    fuga = Yabitz::Model::AuthInfo.new
    fuga.name = "fuga"
    fuga.fullname = "fuga fugawo"
    fuga.valid = false
    fuga.save
    Yabitz::Model::AuthInfo.query(:name => "fuga").size.should eql(1)
    Yabitz::Model::AuthInfo.query(:name => "fuga", :valid => false).size.should eql(1)
    Yabitz::Model::AuthInfo.authenticate("fuga", "dummypass", "192.168.2.1").should be_nil
  end

  it "に .all でリストを要求したら :name でソートされたリストを返すこと" do
    Stratum.conn do |c|
      c.query("DELETE FROM #{Yabitz::Model::AuthInfo.tablename}")
    end
    ["tago", "moris", "hoges", "posmos", "arias", "zas"].each do |str|
      Yabitz::Model::AuthInfo.query_or_create(:name => str, :fullname => str)
    end

    Yabitz::Model::AuthInfo.all(:sorted => true).map(&:name).should eql(["arias", "hoges", "moris", "posmos", "tago", "zas"])
  end
end
