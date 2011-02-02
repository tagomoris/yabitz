# -*- coding: utf-8 -*-

require_relative '../lib/yabitz/misc/refupdator'

class RefUpdatorTest
  def oid ; self.object_id ; end
  def save ; @saved = true ; end
  def saved? ; @saved ||= false ; @saved ; end
end
class RefUA < RefUpdatorTest
  attr_accessor :x, :x_by_id
end
class RefUB < RefUpdatorTest
  def xs
    @xs ||= []
    @xs
  end
  def xs_by_id
    @xs ||= []
    @xs
  end
  def xs_by_id=(ary)
    @xs = ary
  end
end
class RefUC < RefUpdatorTest
end

describe Yabitz::RefUpdator do
  before(:all) do
    @cls = Yabitz::RefUpdator
  end

  it "の .update について nil と obj を与えたとき obj の fieldlist に target_id が代入され #save が呼ばれること" do
    ua = RefUA.new
    @cls.update(1, nil, ua, [:x, :xs])
    ua.x_by_id.should eql(1)
    ua.saved?.should be_true

    ub1 = RefUB.new
    @cls.update(1, nil, ub1, [:x, :xs])
    ub1.xs_by_id.should eql([1])
    ub1.saved?.should be_true

    ub2 = RefUB.new
    ub2.xs_by_id = [5,3]
    @cls.update(1, nil, ub2, [:x, :xs])
    ub2.xs_by_id.should eql([5,3,1])
    ub2.saved?.should be_true

    ub3 = RefUB.new
    ub3.xs_by_id = [10,1,100]
    @cls.update(1, nil, ub3, [:x, :xs])
    ub3.xs_by_id.should eql([10,100,1])
    ub3.saved?.should be_true

    uc = RefUC.new
    @cls.update(1, nil, uc, [:x, :xs])
    uc.saved?.should be_false
  end

  it "の .update について obj と nil を与えたとき obj の fieldlist から target_id が取り除かれ #save が呼ばれること" do
    ua = RefUA.new
    ua.x_by_id = 10
    @cls.update(10, ua, nil, [:x, :xs])
    ua.x_by_id.should be_nil
    ua.saved?.should be_true

    ub1 = RefUB.new
    ub1.xs_by_id = [10]
    @cls.update(10, ub1, nil, [:x, :xs])
    ub1.xs_by_id.should eql([])
    ub1.saved?.should be_true

    ub2 = RefUB.new
    ub2.xs_by_id = [20,10]
    @cls.update(10, ub2, nil, [:x, :xs])
    ub2.xs_by_id.should eql([20])
    ub2.saved?.should be_true

    ub3 = RefUB.new
    ub3.xs_by_id = [100,10,3]
    @cls.update(10, ub3, nil, [:x, :xs])
    ub3.xs_by_id.should eql([100,3])
    ub3.saved?.should be_true
    
    uc = RefUC.new
    @cls.update(100, uc, nil, [:x, :xs])
    uc.saved?.should be_false
  end

  it "の .update について obj と obj を与えたとき obj に対して何も行われず #save も呼ばれないこと" do
    ua = RefUA.new
    ua.x_by_id = 10
    @cls.update(10, ua, ua, [:x, :xs])
    ua.x_by_id.should eql(10)
    ua.saved?.should be_false

    ub1 = RefUB.new
    ub1.xs_by_id = [10]
    @cls.update(10, ub1, ub1, [:x, :xs])
    ub1.xs_by_id.should eql([10])
    ub1.saved?.should be_false

    ub2 = RefUB.new
    ub2.xs_by_id = [20,10]
    @cls.update(10, ub2, ub2, [:x, :xs])
    ub2.xs_by_id.should eql([20,10])
    ub2.saved?.should be_false

    ub3 = RefUB.new
    ub3.xs_by_id = [100,10,3]
    @cls.update(10, ub3, ub3, [:x, :xs])
    ub3.xs_by_id.should eql([100,10,3])
    ub3.saved?.should be_false
    
    uc = RefUC.new
    @cls.update(100, uc, uc, [:x, :xs])
    uc.saved?.should be_false
  end

  it "の .update について [] と [obj] を与えたとき obj の fieldlist に target_id が代入され #save が呼ばれること" do
    ua = RefUA.new
    @cls.update(1, [], [ua], [:x, :xs])
    ua.x_by_id.should eql(1)
    ua.saved?.should be_true

    ub1 = RefUB.new
    @cls.update(1, [], [ub1], [:x, :xs])
    ub1.xs_by_id.should eql([1])
    ub1.saved?.should be_true

    ub2 = RefUB.new
    ub2.xs_by_id = [5,3]
    @cls.update(1, [], [ub2], [:x, :xs])
    ub2.xs_by_id.should eql([5,3,1])
    ub2.saved?.should be_true

    ub3 = RefUB.new
    ub3.xs_by_id = [10,1,100]
    @cls.update(1, [], [ub3], [:x, :xs])
    ub3.xs_by_id.should eql([10,100,1])
    ub3.saved?.should be_true

    uc = RefUC.new
    @cls.update(1, [], [uc], [:x, :xs])
    uc.saved?.should be_false
  end
  
  it "の .update について [obj] と [] を与えたとき obj の fieldlist から target_id が取り除かれ #save が呼ばれること" do
    ua = RefUA.new
    ua.x_by_id = 10
    @cls.update(10, [ua], [], [:x, :xs])
    ua.x_by_id.should be_nil
    ua.saved?.should be_true

    ub1 = RefUB.new
    ub1.xs_by_id = [10]
    @cls.update(10, [ub1], [], [:x, :xs])
    ub1.xs_by_id.should eql([])
    ub1.saved?.should be_true

    ub2 = RefUB.new
    ub2.xs_by_id = [20,10]
    @cls.update(10, [ub2], [], [:x, :xs])
    ub2.xs_by_id.should eql([20])
    ub2.saved?.should be_true

    ub3 = RefUB.new
    ub3.xs_by_id = [100,10,3]
    @cls.update(10, [ub3], [], [:x, :xs])
    ub3.xs_by_id.should eql([100,3])
    ub3.saved?.should be_true
    
    uc = RefUC.new
    @cls.update(100, [uc], [], [:x, :xs])
    uc.saved?.should be_false
  end
  
  it "の .update について [obj] と [obj] を与えたとき obj に対して何も行われず #save も呼ばれないこと" do 
    ua = RefUA.new
    ua.x_by_id = 10
    @cls.update(10, [ua], [ua], [:x, :xs])
    ua.x_by_id.should eql(10)
    ua.saved?.should be_false

    ub1 = RefUB.new
    ub1.xs_by_id = [10]
    @cls.update(10, [ub1], [ub1], [:x, :xs])
    ub1.xs_by_id.should eql([10])
    ub1.saved?.should be_false

    ub2 = RefUB.new
    ub2.xs_by_id = [20,10]
    @cls.update(10, [ub2], [ub2], [:x, :xs])
    ub2.xs_by_id.should eql([20,10])
    ub2.saved?.should be_false

    ub3 = RefUB.new
    ub3.xs_by_id = [100,10,3]
    @cls.update(10, [ub3], [ub3], [:x, :xs])
    ub3.xs_by_id.should eql([100,10,3])
    ub3.saved?.should be_false
    
    uc = RefUC.new
    @cls.update(100, [uc], [uc], [:x, :xs])
    uc.saved?.should be_false
  end
end
