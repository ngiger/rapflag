require 'csv'
require 'open-uri'
require 'faraday'

module RAPFLAG

  class History
    attr_reader :history, :wallet, :currency, :btc_to_usd, :bfx_to_usd
    DATE_FORMAT = '%Y.%m.%d'
    DATE_TIME_FORMAT = '%Y.%m.%d %H:%M:%S'

    def initialize(wallet = 'trading', currency = 'USD')
      @btc_to_usd = {}
      @bfx_to_usd = {}
      @wallet = wallet
      @currency = currency
    end

    def get_usd_exchange(date_time = Time.now, from='BTC')
      return 1.0 if from == 'USD'
      key = date_time.strftime(DATE_FORMAT)
      return @btc_to_usd[key] if from.eql?('BTC') && @btc_to_usd.size > 0
      return @bfx_to_usd[key] if from.eql?('BFC') && @bfx_to_usd.size > 0

      ms =  (date_time.is_a?(Date) ? date_time.to_time : date_time).to_i*1000
      ms_next_date = ms + (3*24*3600)*1000
      # this does not work
      # url = "https://api.bitfinex.com/v2/candles/trade:1D:t#{from}USD/hist?start:#{ms}?end:#{ms_next_date}"
      url = "https://api.bitfinex.com/v2/candles/trade:1D:t#{from}USD/hist?start:#{ms}?end:#{ms_next_date}"
      # therefore we just return the most uptodate
      url = "https://api.bitfinex.com/v2/candles/trade:1D:t#{from}USD/hist?start:#{Time.now.to_i*1000}"
      response = Faraday.get(url)
      items = eval(response.body)
      rates = {}
      items.each do |item|
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
      from.eql?('BTC') ? @btc_to_usd = rates : @bfx_to_usd = rates
      rates[key] ? rates[key] : nil
    end

    def fetch_csv_history
      client = Bitfinex::Client.new
      @history = []
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

    # Configure the client with the proper KEY/SECRET, you can create a new one from:
    # https://www.bitfinex.com/api
    def create_csv_file
      out_file = "output/#{@wallet}_#{@currency}.csv"
      FileUtils.makedirs(File.dirname(out_file))
      CSV.open(out_file,'w',
          :write_headers=> true,
          :headers => ['currency',
                      'amount',
                      'balance',
                      'description',
                      'date_time',
                      ] #< column header
        ) do |csv|
        @history.each do | hist_item|
          csv << [ hist_item['currency'],
                  hist_item['amount'],
                  hist_item['balance'],
                  hist_item['description'],
                    Time.at(hist_item['timestamp'].to_i).strftime(DATE_TIME_FORMAT),
                  ]
        end
      end

      sums = {}
      @history.each do | hist_item|
        key = /^[^\d]+/.match(hist_item['description'])[0].chomp
        value = hist_item['amount'].to_f
        if sums[key]
          sums[key] +=  value
        else
          sums[key]  =  value
        end
      end

      puts
      puts "Summary for #{@wallet} #{@currency} (#{@history.size} entries}"
      sums.each do |key, value|
        puts " #{sprintf('%40s', key)} is #{value}"
      end
    end

    Struct.new("Daily", :date, :amount, :balance, :description, :income)
    def create_summary
      @daily = {}
      @history.sort{|x,y| x['timestamp'] <=> y['timestamp']}.each do | hist_item|
        date = Time.at(hist_item['timestamp'].to_i).strftime(DATE_FORMAT)
        info = Struct::Daily.new(date, hist_item['amount'].to_f, hist_item['balance'].to_f, hist_item['description'])
        amount = hist_item['amount'].to_f
        balance = hist_item['balance'].to_f
        if @daily[date]
          old_balance = @daily[date]
          existing = @daily[date]
        else
          info.income = 0.0
          existing = info
        end
        if /Wire Withdrawal fee|Trading fees for|Margin Funding Payment on wallet/i.match( hist_item['description'])
          existing.income += amount
        end
        existing.balance = balance if balance != 0.0
        @daily[date] = existing
      end
      out_file = "output/#{@wallet}_#{@currency}_summary.csv"
      FileUtils.makedirs(File.dirname(out_file))
      CSV.open(out_file,'w',
          :write_headers=> true,
          :headers => ['currency',
                       'date',
                      'income',
                      'balance',
                      'balance_in_usd',
                      ] #< column header
        ) do |csv|
        @daily.each do |date, info|
          strings = date.split('.')
          fetch_date = Date.new(strings[0].to_i, strings[1].to_i, strings[2].to_i)
          rate = get_usd_exchange(fetch_date, @currency)
          csv << [@currency,
                  date,
                  info.income,
                  info.balance,
                  rate ? info.balance * get_usd_exchange(fetch_date, @currency) : nil,
                 ]
        end
      end
    end
  end
end
