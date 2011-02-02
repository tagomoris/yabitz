# -*- coding: utf-8 -*-

$YABITZ_RUN_ON_TEST_ENVIRONMENT = true
require_relative '../../lib/yabitz/misc/init'
require_relative '../../scripts/db_schema'

require_relative '../../lib/yabitz/misc/logging'

describe Yabitz::Logging do
  before(:all) do
    Yabitz::Schema.setup_test_db()
  end
  
  after(:all) do
    Yabitz::Schema.teardown_test_db()
  end

  it "によって認証ログがテーブルに記録されること" do
    Stratum.conn do |c|
      c.query("SELECT count(*) FROM auth_log").fetch_row.first.should eql("0")
      Yabitz::Logging.log_auth("tagomoris", "success")
      Yabitz::Logging.log_auth("moris", "failed")
      Yabitz::Logging.log_auth("tago", "forbidden")
      c.query("SELECT count(*) FROM auth_log").fetch_row.first.should eql("3")
    end
  end
end
