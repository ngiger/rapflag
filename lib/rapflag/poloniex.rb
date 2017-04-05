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
    attr_reader :balances, :active_loans, :lendings, :withdrawls,:addrs,
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
      binding.pry if defined?(MiniTest)
    end

    def dump_history
      load_history_info
      CSV.open('output/active_loans.csv', 'w',
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
      CSV.open('output/lending_history.csv','w',
               :col_sep => ';',
               :write_headers=> true,
               :headers => [ 'id', 'currency', 'rate', 'amount', 'duration', 'interest', 'fee', 'earned', 'open', 'close', ]
        ) do |csv|
        @lending_history.each do |info|
          csv << info.values
        end
      end
      CSV.open('output/trade_history.csv','w',
               :col_sep => ';',
               :write_headers=> true,
               :headers => [ 'globalTradeID', 'tradeID', 'date', 'rate', 'amount', 'total', 'fee', 'orderNumber', 'type', 'category', ]
        ) do |csv|
        @trade_history.each do |currency_pair, trades|
          trades.each do |trace|
            csv << [ currency_pair] + trace.values
          end
        end
      end
      CSV.open('output/tradable_balances.csv','w',
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
      CSV.open('output/deposits_withdrawls.csv','w',
               :col_sep => ';',
               :write_headers=> true,
               :headers => [ 'key', 'withdrawalNumber', 'currency', 'address', 'amount', 'timestamp', 'status', 'ipAddress' ]
        ) do |csv|
       @deposits_withdrawls.each do |key, balance|
          balance.each do |info|
            csv << [ key] + info.values
          end
        end
      end
      File.open('output/available_account_balances.txt','w'){ |f| f.puts @available_account_balances.inspect}
    end
    def fetch_csv_history
      load_history_info
      @history = []
      @deposits_withdrawls.keys.each do |operation|
        @deposits_withdrawls[operation].each do |movement|
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
    def load_history_info
      check_config
      return if @balances && @balances.size > 0
      begin
        @balances = JSON.parse(::Poloniex.balances.body)
      rescue => error
        puts "Error was #{error.inspect}"
        puts "Calling @balances from poloniex failed. Configuration was"
        pp ::Poloniex.configuration
        binding.pry if defined?(Pry)
        exit 1
      end
      @active_loans = JSON.parse(::Poloniex.active_loans.body)
      @lending_history = JSON.parse(::Poloniex.lending_history.body)
      @deposits_withdrawls  = JSON.parse(::Poloniex.deposits_withdrawls.body)
      @deposit_addresses = JSON.parse(::Poloniex.deposit_addresses.body)
      @trade_history  = JSON.parse(::Poloniex.trade_history('all').body) # returns []
      @available_account_balances = JSON.parse(::Poloniex.available_account_balances.body)
      @open_orders  = JSON.parse(::Poloniex.open_orders('all').body) # returns 0
      @tradable_balances  = JSON.parse(::Poloniex.tradable_balances.body)
    end
  end
end
