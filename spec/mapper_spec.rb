# -*- coding: utf-8 -*-

require_relative '../lib/yabitz/misc/mapper'

describe Yabitz::Mapper::Generator do
  before(:all) do
    @cls = Yabitz::Mapper::Generator
  end

  it "の .new に :method として :new/:get/:query_or_create/:always_update 以外のものを与えると必ず例外となること" do
    lambda {@cls.new(nil, :method => :x)}.should raise_exception(ArgumentError)
    lambda {@cls.new(nil, :method => :query)}.should raise_exception(ArgumentError)
    lambda {@cls.new(nil, :method => :hoge)}.should raise_exception(ArgumentError)
    lambda {@cls.new(nil, :method => nil)}.should raise_exception(ArgumentError)
  end
  
  it "の .new に :method => :new を指定するとき :class が指定されていないと例外となること" do
    lambda {@cls.new(nil, :method => :new)}.should raise_exception(ArgumentError)
    lambda {@cls.new(nil, :method => :new, :class => String)}.should_not raise_exception(ArgumentError)
  end
  
  it "の .new に :method => :get を指定するとき :class が指定されていて .get に応答しないと例外となること" do
    class HogeA1; end
    class HogeA2; def self.get(x); x; end; end
    lambda {@cls.new(nil, :method => :get)}.should raise_exception(ArgumentError)
    lambda {@cls.new(nil, :method => :get, :class => HogeA1)}.should raise_exception(ArgumentError)
    lambda {@cls.new(nil, :method => :get, :class => HogeA2)}.should_not raise_exception(ArgumentError)
  end
  
  it "の .new に :method => :query_or_create を指定するとき :class および :field が指定されていて :class に指定されたクラスが .query_or_create に応答しないと例外となること" do
    class HogeB1; end
    class HogeB2; def self.query_or_create(x); x; end; end
    lambda {@cls.new(nil, :method => :query_or_create)}.should raise_exception(ArgumentError)
    lambda {@cls.new(nil, :method => :query_or_create, :field => :hoge)}.should raise_exception(ArgumentError)
    lambda {@cls.new(nil, :method => :query_or_create, :class => HogeB2,)}.should raise_exception(ArgumentError)
    lambda {@cls.new(nil, :method => :query_or_create, :class => HogeB1, :field => :hoge)}.should raise_exception(ArgumentError)
    lambda {@cls.new(nil, :method => :query_or_create, :class => HogeB2, :field => :hoge)}.should_not raise_exception(ArgumentError)
  end
  it "の .new に :method => :always_update を指定するとき :proc および :field が指定されていて :proc が #call に応答しないと例外となること" do
    class HogeC1; attr_accessor :c; end
    p1 = Proc.new { HogeC1.new }
    lambda {@cls.new("a", :method => :always_update)}.should raise_exception(ArgumentError)
    lambda {@cls.new("a", :method => :always_update, :field => :c)}.should raise_exception(ArgumentError)
    lambda {@cls.new("a", :method => :always_update, :proc => p1)}.should raise_exception(ArgumentError)
    lambda {@cls.new("a", :method => :always_update, :proc => "hoge", :field => :c)}.should raise_exception(ArgumentError)
    lambda {@cls.new("a", :method => :always_update, :proc => p1, :field => :c)}.should_not raise_exception(ArgumentError)
  end
  
  it "の .new に :new,String を与えた場合に #call_once(val) で新しく作成された文字列が返ること" do
    gen = @cls.new(nil, :method => :new, :class => String)
    str1 = "hoge"
    str2 = gen.call_once(str1)
    str1.should eql(str2)
    str1.object_id.should_not eql(str2.object_id)
  end
  
  it "の .new に :getとKlassを与えた場合に #call_once(val) で Klass.get(val.to_i) の結果が返ること" do
    class PosA1
      attr_accessor :v
      def self.get(v)
        obj = self.new
        obj.v = v * 50 - 1
        obj
      end
    end
    gen = @cls.new(nil, :method => :get, :class => PosA1)
    obj = gen.call_once("1")
    obj.class.should eql(PosA1)
    obj.v.should eql(49)
    gen.call_once("30").v.should eql(1499)
  end
  
  it "の .new に :query_or_createとKlassおよびフィールド名を与えた場合に #call_once(val) で Klass.query_or_create(field => val) の結果が返ること" do
    class PosB1
      attr_accessor :f, :v
      def self.query_or_create(hash)
        unless hash.size == 1
          raise RuntimeError
        end
        obj = self.new
        obj.f = hash.first.first
        obj.v = hash.first.last
        obj
      end
    end
    gen = @cls.new(nil, :method => :query_or_create, :class => PosB1, :field => :hoge)
    obj = gen.call_once("moge")
    obj.class.should eql(PosB1)
    obj.f.should eql(:hoge)
    obj.v.should eql("moge")
  end
  
  it "の .new に :write_throughとKlassおよびフィールド名を与えた場合に #call_once(val) で Klass.query_or_create(field => val).to_s の結果が返ること" do
    class PosP1
      attr_accessor :f, :v
      def self.query_or_create(hash)
        unless hash.size == 1
          raise RuntimeError
        end
        obj = self.new
        obj.f = hash.first.first
        obj.v = hash.first.last
        obj
      end
      def to_s
        self.f.to_s + '---' + self.v.to_s
      end
    end
    gen = @cls.new(nil, :method => :write_through, :class => PosP1, :field => :hoge)
    obj = gen.call_once("moge")
    obj.class.should eql(String)
    obj.should eql("hoge---moge")
  end

  it "の .new に :always_updateと適当なオブジェクトthis、procおよびフィールド名を与えた場合に #call_once(val) で \
       proc.call(this) により得られるオブジェクトの field に val を代入したものが得られること" do
    class PosC1
      attr_accessor :hoge
      attr_accessor :moge
    end
    proc1 = Proc.new {|v| PosC1.new}
    gen1 = @cls.new("a", :method => :always_update, :proc => proc1, :field => :hoge)
    gen2 = @cls.new("a", :method => :always_update, :proc => proc1, :field => :moge)

    obj1 = gen1.call_once("111")
    obj1.class.should eql(PosC1)
    obj1.hoge.should eql("111")

    gen2.call_once("222").moge.should eql("222")
  end

  it "の .new に :always_updateと適当なオブジェクトthis、procおよびフィールド名を与えた場合に #call_once(val) で \
       proc.call(this) により得られるオブジェクトが #save メソッドを持っていれば、val代入後に #save が呼ばれた後のものが得られること" do
    class PosC2
      attr_accessor :hoge
      attr_accessor :moge
      def save
        @saved = true
      end
      def saved?
        @saved ||= false
        @saved
      end
    end
    proc1 = Proc.new {|v| PosC2.new}
    gen1 = @cls.new("a", :method => :always_update, :proc => proc1, :field => :hoge)
    gen2 = @cls.new("a", :method => :always_update, :proc => proc1, :field => :moge)

    obj1 = gen1.call_once("111")
    obj1.class.should eql(PosC2)
    obj1.hoge.should eql("111")
    obj1.saved?.should be_true

    gen2.call_once("222").saved?.should be_true
  end

  it "のインスタンスの #call を空配列を引数に呼んだとき、空配列が返されること" do
    gen = @cls.new(nil, :method => :new, :class => String)
    ret = gen.call([])
    ret.should be_instance_of(Array)
    ret.size.should eql(0)
  end

  it "のインスタンスの #call を呼んだとき、引数が単一のオブジェクトのみの場合(配列でないとき)は単一のオブジェクトが返されること" do
    gen = @cls.new(nil, :method => :new, :class => String)
    hoge = "hoge"
    ret = gen.call(hoge)
    ret.should_not be_instance_of(Array)
    ret.should eql(hoge)
    ret.object_id.should_not eql(hoge)
  end
  
  it "のインスタンスの #call を配列ひとつのみを引数に呼んだとき、配列が返され、サイズが引数と等しいこと" do
    gen = @cls.new(nil, :method => :new, :class => String)
    ary1 = ["a", "b", "c", "x", "y"]
    ary2 = gen.call(ary1)
    ary2.size.should eql(ary1.size)
    ary2.should eql(ary1)
  end
  
  it "のインスタンスの #call を配列ひとつとオブジェクトひとつを引数に呼んだとき、配列が返され、サイズが引数中のオブジェクト数合計と等しいこと" do
    gen = @cls.new(nil, :method => :new, :class => String)
    ary3 = ["1", "b", "three", "IV"]
    ary4 = gen.call(ary3, "go")
    ary4.size.should eql(ary3.size + 1)
    ary4.should eql(ary3 + ["go"])
  end
end

describe Yabitz::Mapper do
  before(:all) do
    @cls = Yabitz::Mapper
  end

  it "を mix-in したクラスで #generate すると .instanciate_mapping の情報を引数に Generator が作成され返されること" do
    class Yabitz::Mapper::Generator
      attr_reader :this, :proc, :field
      def x_method
        @method
      end
      def x_class
        @class
      end
    end
    class MogeA
      attr_accessor :x, :y
      def self.get(x)
        obj = self.new
        obj.x = x * 20
        obj
      end
      def self.query_or_create(hash)
        obj = self.new
        obj.send(hash.first.first.to_s + '=', hash.first.last)
        obj
      end
      def to_s
        self.x.to_s + '/' + self.y.to_s
      end
    end
    class MogeX
      include Yabitz::Mapper
      attr_accessor :y
      def self.instanciate_mapping(fname)
        case fname
        when :a
          {:method => :new, :class => String}
        when :b
          {:method => :get, :class => MogeA}
        when :c
          {:method => :query_or_create, :class => MogeA, :field => :x}
        when :d
          {:method => :write_through, :class => MogeA, :field => :x}
        when :e
          {:method => :always_update, :proc => Proc.new{|this| m = MogeA.new; m.y = this.y; m}, :field => :x}
        end
      end
    end
    moge = MogeX.new
    moge.y = 167

    gen1 = moge.member_generator(:a)
    gen1.this.object_id.should eql(moge.object_id)
    gen1.x_method.should eql(:new)
    gen1.x_class.should eql(String)

    gen2 = moge.member_generator(:b)
    gen2.this.object_id.should eql(moge.object_id)
    gen2.x_method.should eql(:get)
    gen2.x_class.should eql(MogeA)

    gen3 = moge.member_generator(:c)
    gen3.this.object_id.should eql(moge.object_id)
    gen3.x_method.should eql(:query_or_create)
    gen3.x_class.should eql(MogeA)
    gen3.field.should eql(:x)
    
    gen5 = moge.member_generator(:d)
    gen5.this.object_id.should eql(moge.object_id)
    gen5.x_method.should eql(:write_through)
    gen5.x_class.should eql(MogeA)
    gen5.field.should eql(:x)

    gen4 = moge.member_generator(:e)
    gen4.this.object_id.should eql(moge.object_id)
    gen4.x_method.should eql(:always_update)
    gen4.proc.should be_instance_of(Proc)
    gen4.field.should eql(:x)
    
    ary = gen4.call(["hoge", "moge"], "pos")
    ary.size.should eql(3)
    ary.map(&:y).should eql([moge.y, moge.y, moge.y])
    ary.map(&:x).should eql(["hoge", "moge", "pos"])
  end
  
end
