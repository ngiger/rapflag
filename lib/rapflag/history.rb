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
    INCOME_PATTERN = /Settlement|Wire Withdrawal fee|Crypto Withdrawal fee|Trading fees for|Margin Funding Payment on wallet/i

    def initialize(wallet = 'trading', currency = 'USD')
      @wallet = wallet
      @currency = currency
    end

    def create_csv_file
      out_file = File.join(RAPFLAG.outputDir, "#{self.class.to_s.split('::').last.downcase}/#{@currency}_#{@wallet}.csv")
      FileUtils.makedirs(File.dirname(out_file))
      CSV.open(out_file,'w',
          :write_headers=> true,
          :col_sep => COLUMN_SEPARATOR,
          :headers => ['currency',
                      'amount',
                      'balance',
                      'description',
                      'date_time',
                      ] #< column header
        ) do |csv|
        skip_next = false
        @history.each_with_index do | hist_item, index|
          if skip_next
            skip_next = false
            next
          end
          timestamp = Time.at(hist_item['timestamp'].to_i).strftime(DATE_TIME_FORMAT)
          next_timestamp = @history[index+1] && Time.at(@history[index+1]['timestamp'].to_i).strftime(DATE_TIME_FORMAT)
          if next_timestamp.eql?(timestamp)
            next_item = @history[index + 1]
            this_day = Date.parse(timestamp).to_s
            prev_day = (Date.parse(timestamp)-1).to_s
            this_tx = history.find_all{|x| Time.at(x['timestamp'].to_i).to_date.to_s.eql?(this_day)}
            prev_tx = history.find{|x| Time.at(x['timestamp'].to_i).to_date < Date.parse(timestamp)}
            @total = prev_tx ?  prev_tx['balance'].to_f : 0.0
            this_tx.each{|x|to_add =  x['amount'].to_f; @total = @total + to_add}
            if @total == next_item['balance'].to_f
              second = hist_item
              first  = next_item
            else
              first  = hist_item
              second = next_item
            end
            skip_next = true
            csv << [ first['currency'],
                    first['amount'],
                    first['balance'],
                    first['description'],
                    Time.at(first['timestamp'].to_i).strftime(DATE_TIME_FORMAT),
                    ]
            csv << [ second['currency'],
                    second['amount'],
                    second['balance'],
                    second['description'],
                    Time.at(second['timestamp'].to_i).strftime(DATE_TIME_FORMAT),
                    ]
          else
            csv << [ hist_item['currency'],
                    hist_item['amount'],
                    hist_item['balance'],
                    hist_item['description'],
                    timestamp,
                    ]
          end
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
        same_date = @history.select{|v| v['date'].eql?(date)}
        amount = hist_item['amount'].to_f
        balance = hist_item['balance'].to_f
        if @daily[date]
          old_balance = @daily[date]
          existing = @daily[date]
        else
          info.income = 0.0
          existing = info
        end
        if INCOME_PATTERN.match( hist_item['description'])
          existing.income += amount
        end
        existing.balance = balance if balance != 0.0
        puts "#{hist_item} existing #{existing} info #{info} balance #{balance}" if should_break(date)
        @daily[date] = existing
      end
      out_file = File.join(RAPFLAG.outputDir, "#{self.class.to_s.split('::').last.downcase}/#{@currency}_#{@wallet}_summary.csv")
      FileUtils.makedirs(File.dirname(out_file))
      previous_date = nil
      saved_info = nil
      CSV.open(out_file,'w',
          :write_headers=> true,
          :col_sep => COLUMN_SEPARATOR,
          :headers => ['currency',
                       'date',
                      'income',
                      'balance',
                      ] #< column header
        ) do |csv|

        @daily.each do |date, info|
          strings = date.split('.')
          fetch_date = Date.new(strings[0].to_i, strings[1].to_i, strings[2].to_i)
          (1..(fetch_date - previous_date -1).to_i).each do |j|
            intermediate = (previous_date + j).strftime(DATE_FORMAT)
            csv << [@currency,
                    intermediate,
                    "",
                    saved_info.balance,
                  ]
          end if previous_date
          csv << [@currency,
                  date,
                  info.income == 0.0 ? '': info.income,
                  info.balance,
                 ]
          add_total(date, info.income, info.balance)
          previous_date = fetch_date
          saved_info = info
        end
      end
    end
    private
    def should_break(string_date)
      return false
      aDate = Date.parse(string_date)
      @currency.eql?('BTC') && aDate.year == 2017 && aDate.month == 05 && aDate.day == 23
    end
    def add_total(date, income, balance)
      if date.is_a?(String)
        key = [@currency, date]
        sdate = date
      elsif date.is_a?(Date)
        sdate = date.strftime(DATE_FORMAT)
        key = [@currency, sdate]
      end
      @@global_totals[key]    ||= [0, 0]
      if should_break(sdate)
        puts "add_total #{sdate} #{income} #{balance} to #{@@global_totals[key]} #{@wallet}"
        binding.pry
      end
      @@global_totals[key][0] += income
      @@global_totals[key][1] += balance
    end
    public
    def create_total
      this_currency = @@global_totals.select{|v, k| v[0].eql?(@currency)}
      day_index = 1
      sorted = Hash[ this_currency.sort_by { |key, val| key[day_index] } ]
      dates = sorted.keys.collect{|x| x[day_index]}.uniq
      total_filename = File.join(RAPFLAG.outputDir, "#{self.class.to_s.split('::').last.downcase}/#{@currency}_total.csv")
      total_file = CSV.open(total_filename, 'w+',
          :write_headers=> true,
          :col_sep => COLUMN_SEPARATOR,
          :headers => ['currency',
                       'date',
                      'total_income',
                      'total_balance',
                      ] #< column header
        )  do |csv|
        dates.each do |date|
          total_income = 0
          total_balance = 0
          this_day = this_currency.select{|v, k| v[day_index].eql?(date)}
          binding.pry if date && should_break(date)
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
