require 'csv'
require 'open-uri'
require 'faraday'
require 'fileutils'

module RAPFLAG

  class History
    attr_reader :history, :wallet, :currency, :btc_to_usd, :bfx_to_usd
    DATE_FORMAT = '%Y.%m.%d'
    DATE_TIME_FORMAT = '%Y.%m.%d %H:%M:%S'

    def initialize(wallet = 'trading', currency = 'USD')
      @wallet = wallet
      @currency = currency
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
      out_file = "output/#{@currency}_#{@wallet}_summary.csv"
      FileUtils.makedirs(File.dirname(out_file))
      CSV.open(out_file,'w',
          :write_headers=> true,
          :headers => ['currency',
                       'date',
                      'income',
                      'balance',
                      'rate',
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
                  rate ? rate : nil,
                  rate ? info.balance * get_usd_exchange(fetch_date, @currency) : nil,
                 ]
        end
      end
    end
  end
end
