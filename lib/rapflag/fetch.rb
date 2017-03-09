require 'csv'

module RAPFLAG

  class History
    attr_reader :history, :wallet, :currency

    def initialize(wallet = 'trading', currency = 'USD')
      @wallet = wallet
      @currency = currency
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
          first_time = Time.at(partial.first['timestamp'].to_i).strftime('%Y.%m.%d %H:%M:%S')
          last_time = Time.at(partial.last['timestamp'].to_i).strftime('%Y.%m.%d %H:%M:%S')
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
                    Time.at(hist_item['timestamp'].to_i).strftime('%Y.%m.%d %H:%M:%S'),
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
        date = Time.at(hist_item['timestamp'].to_i).strftime('%Y.%m.%d')
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
                      ] #< column header
        ) do |csv|
        @daily.each do |date, info|
          csv << [@currency,
                  date,
                  info.income,
                  info.balance,
                 ]
        end
      end
    end
  end
end
