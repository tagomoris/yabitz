app_dir = File.expand_path(File.dirname(__FILE__))

require 'sinatra'
require app_dir + "/lib/yabitz/app"
set :environment, ENV['RACK_ENV'].to_sym
set :root,	  app_dir
set :app_file,	  File.join(app_dir, 'lib', 'yabitz', 'app.rb')
disable :run

run Yabitz::Application
