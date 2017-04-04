require 'csv'
require 'open-uri'
require 'faraday'
require 'fileutils'
require 'rapflag/history'

module RAPFLAG

  class Bitfinex < History
    @@btc_to_usd = {}
    @@bfx_to_usd = {}

    def get_usd_exchange(date_time = Time.now, from='BTC')
      return 1.0 if from == 'USD'
      key = date_time.strftime(DATE_FORMAT)
      return @@btc_to_usd[key] if from.eql?('BTC') && @@btc_to_usd.size > 0
      return @@bfx_to_usd[key] if from.eql?('BFX') && @@bfx_to_usd.size > 0

      ms =  (date_time.is_a?(Date) ? date_time.to_time : date_time).to_i*1000
      ms_next_date = ms + (3*24*3600)*1000
      # this does not work
      # url = "https://api.bitfinex.com/v2/candles/trade:1D:t#{from}USD/hist?start:#{ms}?end:#{ms_next_date}"
      url = "https://api.bitfinex.com/v2/candles/trade:1D:t#{from}USD/hist?start:#{ms}?end:#{ms_next_date}"
      # therefore we just return the most uptodate
      url = "https://api.bitfinex.com/v2/candles/trade:1D:t#{from}USD/hist?start:#{ms}"
      puts "Fetching #{date_time}: #{url} #{@@btc_to_usd.size} BTC #{@@bfx_to_usd.size} BFX" if $VERBOSE
      response = Faraday.get(url)
      items = eval(response.body)
      rates = {}
      items.each do |item|
        if item.first.eql?(:error)
          puts "Fetching returned #{item}. Aborting"
          exit(1)
        end
        # http://docs.bitfinex.com/v2/reference#rest-public-candles
        # field definitions for  [ MTS, OPEN, CLOSE, HIGH, LOW, VOLUME ],
        # MTS   int   millisecond time stamp
        # OPEN  float   First execution during the time frame
        # CLOSE   float   Last execution during the time frame
        # HIGH  integer   Highest execution during the time frame
        # LOW   float   Lowest execution during the timeframe
        # VOLUME  float   Quantity of symbol traded within the timeframe
        # [[1489363200000,1224.4,1211.2,1238,1206.7,6157.96283895],
        timestamp = Time.at(item.first/1000).strftime(DATE_FORMAT)
        rates[timestamp] = item[2]
      end;
      from.eql?('BTC') ? @@btc_to_usd = rates.clone : @@bfx_to_usd = rates.clone
      rates[key] ? rates[key] : nil
    rescue => err
      puts "Err #{err}"
      binding.pry if defined?(MiniTest)
    end

    def fetch_csv_history
      @history = []
      check_config
      client = ::Bitfinex::Client.new
      timestamp = Time.now.to_i + 1
      while true
        begin
          partial = client.history(@currency, { :limit => 500, :until => timestamp, :wallet => @wallet})
          break unless partial && partial.size > 0
          if partial.is_a?(Hash)
            puts "Got #{partial['error']} while fetching #{@wallet} #{@currency} until #{Time.at(timestamp)}"
            exit 3
          end
          first_time = Time.at(partial.first['timestamp'].to_i).strftime(DATE_TIME_FORMAT)
          last_time = Time.at(partial.last['timestamp'].to_i).strftime(DATE_TIME_FORMAT)
          puts "Feched #{partial.size} @history entries #{first_time} -> #{last_time}"  if $VERBOSE
          timestamp = (partial.last['timestamp'].to_i - 1)
          @history = @history | partial
          break if partial.size <= 1
        rescue => error
          puts "error #{error}"
        end
      end
      puts "Feched #{@history.size} history entries" if $VERBOSE
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
