require 'open-uri'

module CaptainADB
  module FileHelper
    def get_screenshots_files(dir)
      screenshots = []
      regex = /^screenshot.*\.png$/
      begin
        Dir.foreach(dir) do |f|
          if f.match(regex)
            screenshots.unshift(f)
          end
        end
      rescue Exception => e
      end
      screenshots
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