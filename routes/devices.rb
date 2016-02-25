require_relative 'import'
require 'open-uri'


module CaptainADB
  class App < Sinatra::Base
    register Sinatra::Namespace
    include ADB
    include FileHelper

    nexus_server = 'http://nexus-dev/content/repositories/snapshots/com/groupon/merchant/redemption/'
    
    namespace '/api/devices' do
      get '/?' do
        content_type :json
        devices = list_devices_with_details
        if devices.empty?
          session[:device_sn] = nil
          session[:package_name] = nil
        end
        json devices
      end
      
      get '/:device_sn/packages/?' do |device_sn|
        content_type :json
        json list_installed_packages(device_sn)
      end
      
      get '/:device_sn/packages/:package_name/?' do
        content_type :json
        json get_app_info(params[:package_name], params[:device_sn])
      end
      
      delete '/:device_sn/packages/:package_name/?' do
        uninstall_app(params[:package_name], params[:device_sn]) ? 204 : 404
      end
      
      delete '/:device_sn/packages/:package_name/data/?' do
        clear_app(params[:package_name], params[:device_sn]) ? 204 : 404
      end
      
      post '/:device_sn/screenshots/?' do |device_sn|
        content_type :json
        result = take_a_screenshot(settings.screenshot_dir, device_sn)
        settings.screenshot_files = get_screenshots_files(settings.screenshot_dir)
        result.first ? [201, result[1].to_json] : [500, result[1].to_json]
      end

      post '/update_android' do
        install_app_android(params["app_url"])
        redirect '/'
      end

      post '/update_ios' do
        Ios.install_app_ios(params["app_url"])
        redirect '/'
      end

      post '/update_android_groupon' do
        update_groupon_app_android()
      end

      put '/:device_sn/?' do |device_sn|
        request.body.rewind
        json = request.body.read.to_s
        if json && json.length >= 2
          req_data = JSON.parse(json)
          language = req_data['language']
          country = req_data['country']
          if language && country
            change_language(language, country, device_sn)
            return 202
          else
            return 400
          end
        else
          return 400
        end
      end
    end
    
    namespace '/devices' do
      post '/?' do
        session[:device_sn] = params[:device_sn]
        redirect '/'
      end
      
      post '/:device_sn/packages/?' do
        session[:package_name] = params[:package_name]
        redirect '/'
      end
      
      get '/?' do
        @use_d3 = true
        @use_pnotify = true
        @use_fotorama = true
        @use_jquery_ui = true
        settings.screenshot_files = get_screenshots_files(settings.screenshot_dir)
        haml :devices
      end
    end
  end
end