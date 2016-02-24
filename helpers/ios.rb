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
          device['sn'] = device_id
          puts "list_devices_with_details for id: #{device_id} "
          [['release','ProductVersion'], ['model','ProductType']].each do |property_name, property|
            cmd = "ideviceinfo -u #{device_id} | grep #{property}"
            regex = /#{property}\]:\s+\[(.*?)\]$/
            property_value = regex.match(`#{cmd}`.chomp)
            puts "iOS property: #{property.to_s} with value #{property_value}"
            device[property_name] = property_value ? property_value[1] : 'N/A'
          end
          device['app_version'] = "NA"
          device['battery'] = "NA"
          device['brand'] ="NA"
          device['manufacturer'] ="Apple"
          puts "IOS device #{device}"
          devices.push(device)
        end
        devices
      end


    end
  end
end