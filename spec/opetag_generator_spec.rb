# -*- coding: utf-8 -*-

require_relative '../lib/yabitz/misc/opetag_generator'

describe Yabitz::OpeTagGenerator do
  before(:all) do
    @cls = Yabitz::OpeTagGenerator
  end

  it "の .alphabetic_number により、任意の数値の26進表現が下位から任意桁数で取れること" do
    @cls.alphabetic_number(0,1).should eql('A')
    @cls.alphabetic_number(0,2).should eql('AA')
    @cls.alphabetic_number(25,1).should eql('Z')
    @cls.alphabetic_number(25,2).should eql('AZ')
    @cls.alphabetic_number(26,1).should eql('a')
    @cls.alphabetic_number(26,2).should eql('Aa')
    @cls.alphabetic_number(27,2).should eql('Ab')
    @cls.alphabetic_number(51,2).should eql('Az')
    @cls.alphabetic_number(52,2).should eql('BA')
    # A BCDEF GHIJK LMNOP QRSTU VWXYZ abcde fghij klmno pqrst uvwxy z
    @cls.alphabetic_number((52**3)* 14 + (52**2)* 20 + 52* 0 + 8  ,4).should eql('OUAI')
    @cls.alphabetic_number((52**3)* 0  + (52**2)* 11 + 52* 7 + 25 ,4).should eql('ALHZ')
    @cls.alphabetic_number((52**3)* 14 + (52**2)* 20 + 52* 0 + 8  ,2).should eql('AI')
    @cls.alphabetic_number((52**3)* 0  + (52**2)* 11 + 52* 7 + 25 ,3).should eql('LHZ')

    @cls.alphabetic_number((52**3)* 14 + (52**2)* 46 + 52* 0 + 8  ,4).should eql('OuAI')
    @cls.alphabetic_number((52**3)* 0  + (52**2)* 37 + 52*33 + 25 ,4).should eql('AlhZ')
    @cls.alphabetic_number((52**3)* 14 + (52**2)* 20 + 52*26 + 8  ,2).should eql('aI')
    @cls.alphabetic_number((52**3)* 26 + (52**2)* 11 + 52* 7 + 51 ,3).should eql('LHz')
  end

  it "の .match により yyyymmdd + アルファベット5文字の文字列をOpeTagだと判定できること" do
    @cls.match("").should be_false
    @cls.match(" ").should be_false
    @cls.match("　").should be_false
    @cls.match(nil).should be_false
    @cls.match("199912312359AAbbZ").should be_false
    @cls.match("200901012359zzXyz").should be_false
    @cls.match("210001010001aaaaa").should be_false

    @cls.match("201009081426DeAEY").should be_true

    @cls.match("201001010000aaaaa").should be_true
    @cls.match("201001010000ZZZZZ").should be_true
    @cls.match("209912312359aaaaa").should be_true
    @cls.match("209912312359ZZZZZ").should be_true

    @cls.match("201202292359RWsPc").should be_true
  end

  it "の .generate により yyyymmdd + ランダムなアルファベット5文字のタグが得られること" do
    tags = []
    (1 ... 1000).each do |i|
      t = @cls.generate
      @cls.match(t).should be_true
      tags.should_not include(t)
      tags.push(t)
    end
  end
end
