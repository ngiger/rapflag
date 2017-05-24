require 'csv'
require 'open-uri'
require 'faraday'
require 'fileutils'
require 'date'

module RAPFLAG
  class History
    @@global_totals ||= {}
    attr_reader :history, :wallet, :currency, :btc_to_usd, :bfx_to_usd
    DATE_FORMAT = '%Y.%m.%d'
    DATE_TIME_FORMAT = '%Y.%m.%d %H:%M:%S'

    def initialize(wallet = 'trading', currency = 'USD')
      @wallet = wallet
      @currency = currency
    end

    def create_csv_file
      out_file = File.join(RAPFLAG.outputDir, "#{self.class.to_s.split('::').last.downcase}/#{@currency}_#{@wallet}.csv")
      FileUtils.makedirs(File.dirname(out_file))
      CSV.open(out_file,'w',
          :write_headers=> true,
          :col_sep => ';',
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
      out_file = File.join(RAPFLAG.outputDir, "#{self.class.to_s.split('::').last.downcase}/#{@currency}_#{@wallet}_summary.csv")
      FileUtils.makedirs(File.dirname(out_file))
      previous_date = nil
      saved_rate = nil
      saved_info = nil
      CSV.open(out_file,'w',
          :write_headers=> true,
          :col_sep => ';',
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
          (1..(fetch_date - previous_date -1).to_i).each do |j|
            intermediate = (previous_date + j).strftime('%Y.%m.%d')
            csv << [@currency,
                    intermediate,
                    saved_info.income,
                    saved_info.balance,
                    saved_rate ? saved_rate : nil,
                    saved_rate ? info.balance * get_usd_exchange(intermediate, @currency) : nil,
                  ]
            add_total(previous_date, saved_info.income, saved_info.balance)
          end if previous_date
          csv << [@currency,
                  date,
                  info.income,
                  info.balance,
                  rate ? rate : nil,
                  rate ? info.balance * get_usd_exchange(fetch_date, @currency) : nil,
                 ]
          add_total(date, info.income, info.balance)
          previous_date = fetch_date
          saved_info = info
          saved_rate = nil
        end
      end
    end
    private
    def add_total(date, income, balance)
      if date.is_a?(String)
        key = [@currency, @wallet, date]
      elsif date.is_a?(Date)
        sdate = date.strftime(DATE_FORMAT)
        key = [@currency, @wallet,sdate]
      end
      @@global_totals[key]    ||= [0, 0]
      @@global_totals[key][0] += income
      @@global_totals[key][1] += balance
    end

    public
    def create_total
      this_currency = @@global_totals.select{|v, k| v[0].eql?(@currency)}
      sorted = Hash[ this_currency.sort_by { |key, val| key[2] } ]
      dates = sorted.keys.collect{|x| x[2]}.uniq
      total_filename = File.join(RAPFLAG.outputDir, "#{self.class.to_s.split('::').last.downcase}/#{@currency}_total.csv")
      total_file = CSV.open(total_filename, 'w+',
          :write_headers=> true,
          :col_sep => ';',
          :headers => ['currency',
                       'date',
                      'total_income',
                      'total_balance',
                      ] #< column header
        )  do |csv|
        dates.each do |date|
          total_income = 0
          total_balance = 0
          this_day = this_currency.select{|v, k| v[2].eql?(date)}
          this_day.each do |key, info|
            total_income += info[0]
            total_balance += info[1]
          end
          csv << [@currency, date, total_income, total_balance]
        end
      end
    end
  end
end
# currency,date,income,balance
