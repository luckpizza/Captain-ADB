require_relative 'import'
require 'rubygems'
require 'rufus/scheduler'

module CaptainADB

  scheduler = Rufus::Scheduler.new
  scheduler.cron '0 22 * * 1-5' do
    ADB.update_groupon_app_android()
  end
  class App < Sinatra::Base
    register Sinatra::Namespace
    include ADB
    
    namespace '/api' do
      post '/adb/action/restart/?' do
        content_type :json
        result = restart_server
        result.first ? [200, result[1].to_json] : [500, result[1].to_json]
      end
    end
    
    namespace '/' do
      get '/?' do
        redirect '/devices'
      end
    end
  end
end