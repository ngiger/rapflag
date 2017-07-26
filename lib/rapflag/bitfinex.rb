require 'csv'
require 'open-uri'
require 'faraday'
require 'fileutils'
require 'rapflag/history'

module RAPFLAG

  class Bitfinex < History
    @@btc_to_usd = {}
    @@bfx_to_usd = {}
    Delay_in_seconds = 30

    def fetch_csv_history
      @history = []
      check_config
      client = ::Bitfinex::Client.new
      timestamp = Time.now.to_i + 1
      while true
        begin
          partial = nil
          while true
            partial = client.history(@currency, { :limit => 1000, :until => timestamp, :wallet => @wallet})
            if partial.is_a?(Hash) && (partial.size > 0) && partial['error'].eql?('ERR_RATE_LIMIT')
              puts "Got #{partial['error']} while fetching #{@wallet} #{@currency} #{client.history} items"
              puts "  Will wait #{Delay_in_seconds} seconds before retrying"
              sleep(Delay_in_seconds)
            end
            break if partial && partial.is_a?(Array)
          end
          break if partial.size <= 1
          first_time = Time.at(partial.first['timestamp'].to_i).strftime(DATE_TIME_FORMAT)
          last_time = Time.at(partial.last['timestamp'].to_i).strftime(DATE_TIME_FORMAT)
          puts "Fetched #{partial.size} @history entries #{first_time} -> #{last_time}"  if $VERBOSE
          timestamp = (partial.last['timestamp'].to_i - 1)
          @history = @history | partial
        rescue => error
          puts "error #{error}"
          puts " backtrace: #{error.backtrace[0..10].join("\n")}"
        end
      end
      puts "Fetched #{@history.size} history entries" if $VERBOSE
    end
    def dump_history
      unless @history && @history.size > 0
        puts "Skipping dump_history for #{@currency}/#{@wallet} as history is nil or has no entries"
        return
      end
      output_dir = File.join(RAPFLAG.outputDir, "#{self.class.to_s.split('::').last.downcase}")
      FileUtils.makedirs(output_dir) unless File.directory?(output_dir)
      out_file = File.join(output_dir, "#{@currency}_#{@wallet}_history.csv")
      puts "Creating #{out_file}"
      CSV.open(out_file, 'w+',
               :col_sep => COLUMN_SEPARATOR,
               :write_headers=> true,
               :headers => @history.first.keys
        ) do |csv|
        @history.each do |entry|
          csv << entry.values
        end
      end
    end
    private
    def check_config
      Config['websocket_api_endpoint'] ||= 'wss://api.bitfinex.com/ws'
      ['api_key',
       'secret',
       ].each do |item|
          raise "Must define #{item} in config.yml" unless Config[item]
      end
      ::Bitfinex::Client.configure do |conf|
        conf.api_key = Config['api_key']
        conf.secret  = Config['secret']
        conf.websocket_api_endpoint = Config['websocket_api_endpoint']
      end
    end
  end
end
