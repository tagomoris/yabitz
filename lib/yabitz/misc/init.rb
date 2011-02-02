# -*- coding: utf-8 -*-

require 'sinatra'

require_relative '../plugin'
require_relative './config'


ENV['RACK_ENV'] ||= 'development'
if $YABITZ_RUN_ON_TEST_ENVIRONMENT
  ENV['RACK_ENV'] = 'test'
end
set :environment, ENV['RACK_ENV'].to_sym

Yabitz.set_global_environment(ENV['RACK_ENV'].to_sym)

$LOAD_PATH.push(*Yabitz.config().extra_load_path.map{|p| File.expand_path(p)})

require 'stratum'
require_relative '../model'
require_relative './errors'

Stratum::Connection.setup(*(Yabitz.config().dbparams))
Stratum.operator_model(Yabitz::Model::AuthInfo)
