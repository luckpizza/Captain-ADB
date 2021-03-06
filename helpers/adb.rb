require_relative 'io_stream'
require_relative 'ios'
require_relative 'file_helper'
require 'xmlsimple'


def initialize
  @my_mutex = Mutex.new
end

module CaptainADB
  module ADB
    def restart_server
      cmd = 'adb kill-server && adb start-server'
      result = `#{cmd}`.split("\n").last
      if result.nil?
        return [false, {'message' => 'Error, please try again'}]
      else
        result = result.gsub(/\s?\*\s?/, '')
        if result.include?('success')
          return [true, {'message' => result}]
        else
          return [false, {'message' => result}]
        end
      end
    end
    
    def list_devices
      list = `adb devices`
      devices = list.split("\n").inject([]) do |devices, device|
        device_info = device.split("\t")
        if device_info.size == 2
          devices.push(device_info.first)
        else
          devices
        end
      end
    end

    def list_devices_with_details
      devices = list_devices.inject([]) do |devices, device_sn|
        device = {}
        device['sn'] = device_sn
        ['ro.product.manufacturer', 'ro.product.model', 'ro.build.version.release'].each do |property|
          cmd = "adb -s #{device_sn} shell getprop | grep '#{property}'"
          regex = /#{property}\]:\s+\[(.*?)\]$/
          property_value = regex.match(`#{cmd}`.chomp)
          puts property.to_s
          property_name = property.to_s.gsub(/(.*\.)*/, "")
          device[property_name] = property_value ? property_value[1] : 'N/A'
        end
        device['app_version'] = `adb -s #{device_sn} shell dumpsys package com.groupon.redemption | egrep versionName`.gsub(/(.*=)/, "")
        device['battery'] = `adb -s #{device_sn} shell dumpsys battery | grep level`.gsub(/.*:/, "")
        puts "android device: #{device}"
        devices.push(device)
      end
      Ios.list_devices_with_details.each do |ios_device|
        devices.push(ios_device)
      end
      puts "All devices: #{devices}"
      devices
    end
    
    def list_installed_packages(device_sn = nil)
      cmd = PrivateMethods.synthesize_command('adb shell pm list packages', device_sn)
      `#{cmd}`.split("\n").map! { |pkg| pkg.gsub(/^package:/, '').chomp }
    end
    
    def take_a_screenshot(dir, device_sn = nil)
      dir = dir.gsub(/\/$/, '') + '/'
      system("mkdir -p #{dir}")
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S_%L')
      file_path = "#{dir}screenshot_#{timestamp}.png"
      cmd = 'adb shell screencap -p'
      cmd = PrivateMethods.synthesize_command(cmd, device_sn)
      data = `#{cmd}`.encode('ASCII-8BIT', 'binary').gsub(/\r\n/, "\n")
      begin
        File.open(file_path, 'w') { |f| f.write(data) }
      rescue Exception => e
        return [false, {'message' => e.message, 'backtrace' => e.backtrace}]
      end
      return [true, {'file_path' => file_path}]
    end
    
    def get_app_info(package_name, device_sn = nil)
      cmd = PrivateMethods.synthesize_command("adb shell dumpsys package #{package_name}", device_sn)
      result = `#{cmd}`.chomp.match(/Packages:(.*|\n?)+\z/)[0].gsub(/Packages:\r?\n/, '').gsub(/^.*Package.*\r?\n/, '')
      info = []
      number_of_leading_spaces = result.match(/^(\s+)/)[1].size
      result.gsub(/^[^=]+:.*$/, '').gsub(/^[^=:]*$/, '').gsub(/\s+(\w+=)/, '→\1').gsub(/\r?\n/, '').split('→').reject(&:empty?).map(&:chomp).each do |x|
        pair = x.split('=')
        key = pair.first
        value = pair.last
        if value.match(/\[.*\]/)
          info.push({key => value.split(/\[|\]|\s|,/).reject(&:empty?)})
        else
          info.push({key => value})
        end
      end
      result.gsub(/\r\n^\s{#{number_of_leading_spaces + 1},}/, ' ').scan(/^\s{#{number_of_leading_spaces}}([^=]*?):\s+(.*)/).each do |x|
        info.push({x.first => x.last.chomp.split(/\s+/)})
      end
      info
    end

    def install_app_android(url)
      local_path = "/tmp/app.apk"
      @my_mutex.synchronize do
        download_file(url, local_path)
        list_devices.inject([]) do |devices, device_sn|
          puts "installing app in device #{device_sn}"
          cmd = PrivateMethods.synthesize_command("adb install -reinstall #{local_path}", device_sn)
          puts cmd
          puts `#{cmd}`.chomp
        end
      end
    end

    def uninstall_app(package_name, device_sn = nil)
      cmd = PrivateMethods.synthesize_command("adb uninstall #{package_name}", device_sn)
      result = `#{cmd}`.chomp
      if result == 'Success'
        return true
      elsif result == 'Failure'
        return false
      else
        return false
      end
    end

    def clear_app(package_name, device_sn = nil)
      cmd = PrivateMethods.synthesize_command("adb shell pm clear #{package_name}", device_sn)
      result = `#{cmd}`.chomp
      if result == 'Success'
        return true
      elsif result == 'Failed'
        return false
      else
        return false
      end
    end
    
    def input_keyevent(keyevent, device_sn = nil)
      # keyevent should < KeyEvent.getMaxKeyCode()
      if (keyevent.to_i.to_s == keyevent.to_s) && (keyevent.to_i >= 0 && keyevent.to_i <= 221)
        cmd = PrivateMethods.synthesize_command("adb shell input keyevent #{keyevent}", device_sn)
        `#{cmd}`
        return true
      else
        return false
      end
    end
    
    def input_text(text, device_sn = nil)
      text = text.gsub(/\s/, '%s')
      cmd = PrivateMethods.synthesize_command("adb shell input text #{text}", device_sn)
      `#{cmd}`
    end
    
    def press_power_button(device_sn = nil)
      keycode_power = 26
      input_keyevent(keycode_power, device_sn)
    end
    
    # Precondition: device needs to be rooted
    def change_language(language, country, device_sn = nil)
      cmd = PrivateMethods.synthesize_command("adb shell \"su -c 'setprop persist.sys.language #{language}; setprop persist.sys.country #{country}; stop; sleep 5; start'\"", device_sn)
      `#{cmd}`
    end
    
    def is_device_rooted?(device_sn = nil)
      cmd = PrivateMethods.synthesize_command("adb shell 'which su; echo $?'", device_sn)
      exit_status = `#{cmd}`.split(/\r\n/)[1].to_i
      return exit_status == 0
    end

    def start_monkey_test(package_name, device_sn = nil, options = {})
      numbers_of_events = options.fetch(:numbers_of_events, 50000)
      cmd = PrivateMethods.synthesize_command("adb shell monkey -p #{package_name} -v #{numbers_of_events}", device_sn)
      IoStream.redirect_command_output(cmd) do |line|
        puts line
      end
    end
    
    def stop_monkey_test
      `adb shell ps | awk '/com\.android\.commands\.monkey/ { system("adb shell kill " $2) }'`
    end

    def update_groupon_app_android()
      data = nil
      open(nexus_server + 'maven-metadata.xml') do |io|
        data = io.read
      end
      xml =  XmlSimple.xml_in(data)
      last_version = xml['versioning'][0]['latest'][0]
      open("#{nexus_server}#{last_version}/maven-metadata.xml") do |io|
        data = io.read
      end
      xml =  XmlSimple.xml_in(data)
      puts xml
      puts "snapshotVersion.... "
      puts xml['versioning'][0]["snapshotVersions"][0]['snapshotVersion'][0]['value'][0]
      apk_name = xml['versioning'][0]["snapshotVersions"][0]['snapshotVersion'][0]['value'][0]
      install_app_android("#{nexus_server}#{last_version}/#{xml['artifactId'][0]}-#{apk_name}.apk")
    end

    class PrivateMethods
      class << self
        def synthesize_command(cmd, device_sn)
          if device_sn.nil?
            cmd
          else
            # -s <specific device>
            cmd.gsub(/^adb\s/, "adb -s #{device_sn} ")
          end
        end
      end
    end
  end
end