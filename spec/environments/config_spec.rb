# -*- coding: utf-8 -*-

require_relative '../../lib/yabitz/misc/config'

describe Yabitz::Config do 
  it "において、各環境用のモジュールから DATABASE パラメータを正常に取得できること" do
    db1 = Yabitz::Config::Production::DATABASE
    db1.has_key?(:server).should be_true
    db1.has_key?(:user).should be_true
    db1.has_key?(:pass).should be_true
    db1.has_key?(:name).should be_true
    db1.has_key?(:port).should be_true
    db1.has_key?(:sock).should be_true

    db2 = Yabitz::Config::Development::DATABASE
    db2.has_key?(:server).should be_true
    db2.has_key?(:user).should be_true
    db2.has_key?(:pass).should be_true
    db2.has_key?(:name).should be_true
    db2.has_key?(:port).should be_true
    db2.has_key?(:sock).should be_true

    db3 = Yabitz::Config::Test::DATABASE
    db3.has_key?(:server).should be_true
    db3.has_key?(:user).should be_true
    db3.has_key?(:pass).should be_true
    db3.has_key?(:name).should be_true
    db3.has_key?(:port).should be_true
    db3.has_key?(:sock).should be_true
  end
  
  # don't run when rspec runs all of specs
  #
  # it "において、設定セットを行わずに config の取得を行うと例外となること" do
  #   lambda {Yabitz.config()}.should raise_exception(RuntimeError)
  # end
  
  it "において、適当なシンボルを設定名としてセットすると例外となること" do
    lambda {Yabitz.set_global_environment(:moge)}.should raise_exception(ArgumentError)
  end
  
  it "において :testをセットすることでテスト環境用のDB接続用のパラメータが正常に取得できること" do
    db = Yabitz::Config::Test::DATABASE
    Yabitz.set_global_environment(:test)
    conf = Yabitz.config()
    conf.dbparams.should eql([db[:server], db[:user], db[:pass], db[:name], db[:port], db[:sock]])
  end
  
  it "において :devをセットすることで開発環境用のDB接続用のパラメータが正常に取得できること" do
    db = Yabitz::Config::Development::DATABASE
    Yabitz.set_global_environment(:dev)
    conf = Yabitz.config()
    conf.dbparams.should eql([db[:server], db[:user], db[:pass], db[:name], db[:port], db[:sock]])
  end

  it "において :developmentをセットすることで開発環境用のDB接続用のパラメータが正常に取得できること" do 
    db = Yabitz::Config::Development::DATABASE
    Yabitz.set_global_environment(:development)
    conf = Yabitz.config()
    conf.dbparams.should eql([db[:server], db[:user], db[:pass], db[:name], db[:port], db[:sock]])
  end
  
  it "において :productionをセットすることで本番環境用のDB接続用のパラメータが正常に取得できること" do 
    db = Yabitz::Config::Production::DATABASE
    Yabitz.set_global_environment(:production)
    conf = Yabitz.config()
    conf.dbparams.should eql([db[:server], db[:user], db[:pass], db[:name], db[:port], db[:sock]])
  end

  it "において :prodをセットすることで本番環境用のDB接続用のパラメータが正常に取得できること" do 
    db = Yabitz::Config::Production::DATABASE
    Yabitz.set_global_environment(:prod)
    conf = Yabitz.config()
    conf.dbparams.should eql([db[:server], db[:user], db[:pass], db[:name], db[:port], db[:sock]])
  end
end
