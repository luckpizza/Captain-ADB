module CaptainADB
  class Ios
    class << self
      require 'plist'

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
          device['sn'] = device_id
          puts "list_devices_with_details for id: #{device_id} "
          [['release','ProductVersion'], ['model','ProductType']].each do |property_name, property|
            cmd = "ideviceinfo -u #{device_id} | grep #{property}"
            puts "IOS command: #{cmd}"
            regex = /\s+(.*?)$/
            result = `#{cmd}`.chomp
            puts "IOS result: #{result}"
            property_value = regex.match(result)
            puts "iOS property: #{property.to_s} with value #{property_value}"
            device[property_name] = property_value ? property_value[1] : 'N/A'
          end
          cmd = "idevicediagnostics diagnostics All -u #{device_id}"
          puts "device info IOS command: #{cmd} "
          result = `#{cmd}`
          puts "plist resul is #{result}"
          plist = Plist::parse_xml result
          device['battery'] = plist['GasGauge']['DesignCapacity'] * 100 / plist['GasGauge']['FullChargeCapacity']
          cmd = "ideviceinstaller -l -u #{device_id}"
          result = `#{cmd}`
          pkg = "com.groupon.redemption.enterprise - Merchant"
          regex = /#{pkg}+(.*?)$/
          app_version = regex.match(result)
          app_version = app_version.nil? ? "N/A" : app_version[1]
          device['app_version'] = app_version
              device['manufacturer'] ="Apple"
          puts "IOS device #{device}"
          devices.push(device)
        end
        devices
      end


    end
  end
end