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
    INCOME_PATTERN = /Dividend|distribution|Settlement|Wire Withdrawal fee|Crypto Withdrawal fee|\
Bitcoin Gold snapshot step3 on Funding wallet|Trading fees for|Margin Funding Payment on wallet/i

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
      out_file = File.join(RAPFLAG.outputDir, "#{self.class.to_s.split('::').last.downcase}/#{@currency}_#{@wallet}_summary.csv")
      FileUtils.makedirs(File.dirname(out_file))
      sorted_history =  @history.sort{|x,y| x['timestamp'] <=> y['timestamp']}
      sorted_history.each_with_index do | hist_item, index|
        date = Time.at(hist_item['timestamp'].to_i).strftime(DATE_FORMAT)
        next if @daily[date]
        @balance_last_day = (index == 0) ? 0.0 : sorted_history[index-1]['balance'].to_f
        this_day = Struct::Daily.new(date, 0.0, 0.0, hist_item['description'], 0.0)
        same_date = @history.select{|v| v['date'].eql?(date)}
        same_date.each do |info_item|
          amount = info_item['amount'].to_f
          info_item['time'] = Time.at(hist_item['timestamp'].to_i).utc
          this_day.amount += amount
          this_day.income += amount if INCOME_PATTERN.match(info_item['description'])
        end;
        @balance_last_day += this_day.amount
        this_day.balance = sorted_history[index+same_date.size-1]['balance'].to_f
        unless (diff = (@balance_last_day - sorted_history[index+same_date.size-1]['balance'].to_f)) < 0.01
          # puts "diff #{diff} for #{@currency}:#{index} #{date} #{same_date}"
          # Looks like the exchange rates varied between the day and therefore the calculated diff is not always correct
        end
        @daily[date] = this_day
      end
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
          (1..((fetch_date - previous_date).to_i.-1)).each do |j|
            intermediate = (previous_date + j).strftime(DATE_FORMAT)
            content = [@currency, intermediate, "",  saved_info.balance,]
            csv << content
            add_total(intermediate, 0.0, saved_info.balance)
          end if previous_date
          content = [@currency, date, info.income == 0.0 ? '': info.income, info.balance,]
          csv << content
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
      FileUtils.makedirs(File.dirname(total_filename)) unless File.directory?(File.dirname(total_filename))
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
