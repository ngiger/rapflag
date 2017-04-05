require 'csv'
require 'open-uri'
require 'faraday'
require 'fileutils'
require 'rapflag/history'
require 'poloniex'
require 'json'
require 'pp'

module RAPFLAG

  class Poloniex < History
    attr_reader :complete_balances, :active_loans, :lending_history, :deposits, :withdrawals, :deposit_addresses,
        :trade_history, :available_account_balances, :open_orders, :tradable_balances

    @@btc_to_usd = {}
    @@bfx_to_usd = {}

    def get_usd_exchange(date_time = Time.now, from='BTC')
      return 1.0 if from == 'USD'
      daily  = ::Poloniex.get_all_daily_exchange_rates('BTC_GNT')

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
        timestamp = Time.at(item.first/1000).strftime(DATE_FORMAT)
        rates[timestamp] = item[2]
      end;
      from.eql?('BTC') ? @@btc_to_usd = rates.clone : @@bfx_to_usd = rates.clone
      rates[key] ? rates[key] : nil
    rescue => err
      puts "Err #{err}"
    end

    def dump_history
      load_history_info
      FileUtils.makedirs('output') unless File.directory?('output')
      CSV.open('output/trade_history.csv','w+',
               :col_sep => ';',
               :write_headers=> true,
               :headers => [ 'currency_pair'] + @trade_history.values.first.first.to_h.keys
        ) do |csv|
        @trade_history.each do |currency_pair, trades|
          trades.each do |trace|
            csv << [ currency_pair] + trace.to_h.values
          end
        end
      end
      CSV.open('output/lending_history.csv','w+',
               :col_sep => ';',
               :write_headers=> true,
               :headers => @lending_history.first.to_h.keys
        ) do |csv|
        @lending_history.each do |info|
          csv << info.to_h.values
        end
      end
      CSV.open('output/tradable_balances.csv','w+',
               :col_sep => ';',
               :write_headers=> true,
               :headers => [ 'from_currency', 'to_from_currency', ]
        ) do |csv|
        @tradable_balances.each do |currency_pair, balance|
          balance.each do |info|
            csv << [ currency_pair] + info
          end
        end
      end
      CSV.open('output/complete_balances.csv', 'w+',
               :col_sep => ';',
               :write_headers=> true,
               :headers => [ 'currency', 'available', 'onOrders', 'btcValue' ]
        ) do |csv|
        @complete_balances.each do |balance|
          csv << [balance[0]] + balance[1].values
        end
      end
      CSV.open('output/active_loans.csv', 'w+',
               :col_sep => ';',
               :write_headers=> true,
               :headers => [ 'key', 'id', 'currency', 'rate', 'amount', 'duration', 'autoRenew', 'date', 'fees', ]
        ) do |csv|
        @active_loans.each do |key, loans|
          loans.each do | loan |
            csv << [key] + loan.values
          end
        end
      end

      CSV.open('output/available_account_balances.csv', 'w+',
               :col_sep => ';',
               :write_headers=> true,
               :headers => [ 'key', 'currency', 'balance']
        ) do |csv|
        @available_account_balances.each do |key, balances|
          balances.each do |currency, balance|
            csv << [key, currency, balance]
          end
        end
      end
      CSV.open('output/deposit_addresses.csv', 'w+',
               :col_sep => ';',
               :write_headers=> true,
               :headers => [ 'currency', 'id']
        ) do |csv|
        @deposit_addresses.each do |currency, id|
          csv << [currency, id]
        end
      end
      CSV.open('output/withdrawals.csv','w+',
               :col_sep => ';',
               :write_headers=> true,
               :headers => @deposits.first.to_h.keys
        ) do |csv|
        @deposits.each do |info|
          csv << info.to_h.values
        end
      end
      CSV.open('output/deposits.csv','w+',
               :col_sep => ';',
               :write_headers=> true,
               :headers => @withdrawals.first.to_h.keys
        ) do |csv|
        @withdrawals.each do |info|
          csv << info.to_h.values
        end
      end
    end
    def fetch_csv_history
      load_history_info
      binding.pry
      @history = []
      @deposits_withdrawals.keys.each do |operation|
        @deposits_withdrawals[operation].each do |movement|
          example =  {"currency"=>"BTC",
 "amount"=>"-0.00000005",
 "balance"=>"0.0",
 "description"=>"Transfer of 0.0 BTC from wallet Exchange to Deposit on wallet Exchange",
 "timestamp"=>"1480796447.0"}
          next
          @history << example
          to_add = { 'currency'    => movement['currency'],
                     'amount'      => movement['amount'],
                     'timestamp'   => movement['timestamp'],
                     'balance'     => movement[''],
                     'description' => movement[''],
                     }
          first_time = Time.at(movement.first['timestamp'].to_i).strftime(DATE_TIME_FORMAT)
        end
      end
      puts "Fetched #{@history.size} history entries" # if $VERBOSE
    end
    private
    def check_config
      @spec_data = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec', 'data'))
      ['poloniex_api_key',
       'poloniex_secret',
       ].each do |item|
        raise "Must define #{item} in config.yml" unless Config[item]
      end
      ::Poloniex.setup do | config |
          config.key    = Config['poloniex_api_key']
          config.secret = Config['poloniex_secret']
      end
      nil
    end
    private
    def load_or_save_json(name, param = nil)
      json_file = File.join(@spec_data, name.to_s + '.json')
      if File.exist?(json_file) && defined?(MiniTest)
        body = IO.read(json_file)
      else
        cmd = param ? "::Poloniex.#{name.to_s}('#{param}').body" : "::Poloniex.#{name.to_s}.body"
        body = eval(cmd)
        File.open(json_file, 'w+') { |f| f.write(body)}
      end
      eval("@#{name} = JSON.parse(body)")
    end
    def load_history_info
      check_config
      begin
        @balances = load_or_save_json(:balances)
      rescue => error
        puts "Error was #{error.inspect}"
        puts "Calling @balances from poloniex failed. Configuration was"
        pp ::Poloniex.configuration
        exit 1
      end
      @active_loans = load_or_save_json(:active_loans)
      @available_account_balances = load_or_save_json(:available_account_balances)
      all = load_or_save_json(:complete_balances)
      @complete_balances = all.find_all{ | currency, values| values["available"].to_f != 0.0 }
      @deposit_addresses = load_or_save_json(:deposit_addresses)

      @deposits_withdrawals  = load_or_save_json(:deposits_withdrawls)
      # deposits and withdrawals have a different structure
      @deposits = []
      @deposits_withdrawals['deposits'].each {|x| @deposits << OpenStruct.new(x) };
      @withdrawals =[]
      @deposits_withdrawals['withdrawals'].each {|x| @withdrawals << OpenStruct.new(x) };
      info = load_or_save_json(:lending_history)
      @lending_history = []
      info.each {|x| @lending_history << OpenStruct.new(x) };

      @open_orders  = load_or_save_json(:open_orders, 'all')
      info  = load_or_save_json(:trade_history, 'all')
      @trade_history = {}
      info.each do |currency_pair, trades|
        @trade_history[currency_pair] = []
        trades.each {|x| @trade_history[currency_pair] << OpenStruct.new(x) };
        @trade_history[currency_pair].sort!{|x,y| x[:date] <=> y[:date]}.collect{ |x| x[:date]}
      end
      # @trade_history.values.first.first.tradeID
      @tradable_balances  = load_or_save_json(:tradable_balances)
      @active_loans   # key
      @provided_loans = []; @active_loans['provided'].each {|x| @provided_loans << OpenStruct.new(x) };
      @used_loans = []; @active_loans['used'].each {|x| @used_loans << OpenStruct.new(x) };
    end
  end
end
