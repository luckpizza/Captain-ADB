require 'open-uri'

module CaptainADB
  class Ios
    class << self

      def list_devices_ios
        list = `idevice_id -l`
        devices = list.split("\n")
        puts devices
        devices
      end

      def list_devices_with_details
        devices = []
        puts "list_devices_with_details"
        device_ids = list_devices_ios
        device_ids.each do |device_id|
          device = {}
          addDeviceBasicProperties(device, device_id)
          addDeviceBatteryStatus(device, device_id)
          addAppVersion(device, device_id)
          devices.push(device)
        end
        devices
      end

      def addDeviceBasicProperties(device, device_id)
        device['sn'] = device_id
        [['release','ProductVersion'], ['model','ProductType']].each do |property_name, property|
          cmd = "ideviceinfo -u #{device_id} | grep #{property}"
          regex = /\s+(.*?)$/
          result = `#{cmd}`.chomp
          property_value = regex.match(result)
          device[property_name] = property_value ? property_value[1] : 'N/A'
        end
      end

      def addDeviceBatteryStatus(device, device_id)
        device['battery'] = `ideviceinfo -q com.apple.mobile.battery -u #{device_id} -k BatteryCurrentCapacity`
      end

      def addAppVersion(device, device_id)
        cmd = "ideviceinstaller  -u #{device_id} -l | grep groupon.redemption.enterprise"
        result = `#{cmd}`
        pkg = "com.groupon.redemption.enterprise - Merchant"
        regex = /#{pkg}+(.*?)$/
        app_version = regex.match(result)
        app_version = app_version.nil? ? "N/A" : app_version[1]
        device['app_version'] = app_version
        device['manufacturer'] ="Apple"
        puts "IOS device #{device}"
      end

      def install_app_ios(url)
        local_path = "/tmp/app.ipa"
        download_file(url, local_path)
        list_devices_ios.each do |device_sn|
          puts "installing app in device #{device_sn}"
          cmd = "ideviceinstaller -u #{device_sn} -i #{local_path}"
          puts cmd
          puts `#{cmd}`.chomp
        end
      end
      def download_file(url, local_path)
        puts "Downloading app from: #{url}"
        File.open(local_path, "wb") do |saved_file|
          # the following "open" is provided by open-uri
          open(url, "rb") do |read_file|
            saved_file.write(read_file.read)
          end
        end
      end

    end
  end
end