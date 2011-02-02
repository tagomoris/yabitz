# -*- coding: utf-8 -*-

$YABITZ_RUN_ON_TEST_ENVIRONMENT = true

require_relative '../lib/yabitz/misc/init'
require_relative '../lib/yabitz/misc/ldap_handler'

describe Yabitz::LDAPHandler do
  # before(:all) do
  #   @cls = Yabitz::LDAPHandler
  # end

  # it "の .authenticate はusernameもしくはpasswordのどちらかがnilもしくは空文字列であったら必ず失敗を返すこと" do
  #   @cls.authenticate(nil,nil).first.should be_false
  #   @cls.authenticate('','').first.should be_false
  #   @cls.authenticate(nil,'').first.should be_false
  #   @cls.authenticate('',nil).first.should be_false

  #   @cls.authenticate('hoge','').first.should be_false
  #   @cls.authenticate('','hoge').first.should be_false
  #   @cls.authenticate('hoge',nil).first.should be_false
  #   @cls.authenticate(nil,'hoge').first.should be_false
  # end
  
  # must authenticate as correct username/password for ActiveDirectory/LDAP
  # it "の .authenticate はusernameもしくはpasswordがどちらも有効な文字列であった場合、必ず成功を返すこと" do 
  #   @cls.authenticate('a','b').first.should be_true
  #   @cls.authenticate('hoge','pos').first.should be_true
  #   @cls.authenticate('tagomoris','s').first.should be_true
  #   @cls.authenticate('たごもりす','もりす').first.should be_true
  # end
end
