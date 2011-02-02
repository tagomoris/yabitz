# -*- coding: utf-8 -*-

require_relative '../lib/yabitz/misc/validator'

describe Yabitz::Validator do
  before do
    @m = Yabitz::Validator
  end

  it "はメールアドレスの形式の正当性を確認できること" do
    @m.mailaddress('').should be_false
    @m.mailaddress('a').should be_false # without @ mark
    @m.mailaddress('@b').should be_false # without local-part

    @m.mailaddress('a@b').should be_true
    @m.mailaddress('a-a@b.com').should be_true
    @m.mailaddress('a_a.a@host.subdomain.dom.net').should be_true
    @m.mailaddress('docomo..must.-._..die@docomo.ne.jp').should be_true
    @m.mailaddress('kaomoji.>_<.must.die@docomo.ne.jp').should be_true
    @m.mailaddress('mail+address.too.difficult@livedoor.jp').should be_true
    @m.mailaddress('"mail address tooooooooo difficult"@livedoor.jp').should be_true
    @m.mailaddress('0123456789' * 25 + '@a.com').should be_true

    @m.mailaddress('hoge@ pos.com').should be_false
    @m.mailaddress('hoge @pos.com').should be_true # local part is wonderful world
    @m.mailaddress('ho ge@pos.com').should be_true # local part is wonderful world
    @m.mailaddress('hoge@po s.com').should be_false
    @m.mailaddress('0123456789' * 25 + '@ab.com').should be_false # too long (total)
    @m.mailaddress('hoge@x_x.org').should be_false # '_' forbidden in hostname part
  end
  
  it "はホスト名(dns名)の形式の正当性を確認できること" do
    @m.hostname('').should be_false

    @m.hostname('a').should be_true
    @m.hostname('a.b').should be_true
    @m.hostname('A.b.c').should be_true
    @m.hostname('a'*63 + '.' + 'b'*63 + '.' + 'c'*63 + '.' + 'd'*63).should be_true
    @m.hostname('a---b.c.com').should be_true

    @m.hostname('a..b').should be_false
    @m.hostname('a-.b').should be_false
    @m.hostname('-a.b').should be_false
    @m.hostname('.a.b').should be_false
    @m.hostname('a.b.c.').should be_false
    @m.hostname('a_b.c').should be_false
    @m.hostname('a'*64 + '.local').should be_false
    @m.hostname('a'*63 + '.' + 'b'*63 + '.' + 'c'*63 + '.' + 'd'*60 + '.local').should be_false
  end

  it "はv4/v6にかかわらずIPアドレスの正当性を確認でき、バージョンを文字列で戻すこと" do
    @m.ipaddress('').should be_false
    @m.ipaddress(' ').should be_false
    @m.ipaddress('...').should be_false
    
    @m.ipaddress('0.0.0.0').should eql('v4')
    @m.ipaddress('1.2.3.4').should eql('v4')
    @m.ipaddress('192.168.0.1').should eql('v4')
    @m.ipaddress('255.255.255.255').should eql('v4')
    @m.ipaddress('255.255.255.0').should eql('v4')

    @m.ipaddress('2001:0db8:bd05:01d2:288a:1fc0:0001:10ee').should eql('v6')
    @m.ipaddress('0000::0000').should eql('v6')

    @m.ipaddress('256.0.0.0').should be_nil
    @m.ipaddress('1.1.1.1.1').should be_nil
    @m.ipaddress('192.168.0.256').should be_nil
    @m.ipaddress(' 0.0.0.0').should be_nil
    @m.ipaddress('0. 0.0.0').should be_nil
    
    @m.ipaddress('200x:0db8:bd05:01d2:288a:1fc0:0001:10ee').should be_nil
  end
  
  it "は電話番号については基本的にすべて問題なしとするが、最大64文字であること" do
    @m.telnumber('').should be_true
    @m.telnumber(' ').should be_true
    @m.telnumber('03-5155-0100').should be_true
    @m.telnumber('03-5155-0100 または 03-5155-0141').should be_true
    @m.telnumber('03-5155-0141 内線5614').should be_true
    @m.telnumber('03-5155-0141 (5614)').should be_true
    @m.telnumber('0'*64).should be_true

    @m.telnumber('0'*65).should be_false
  end
end
