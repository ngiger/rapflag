#!/usr/bin/env ruby
require 'bitfinex-api-rb'
require 'yaml'
require 'csv'
require 'pp'
begin
require 'pry'
rescue LOAD_ERROR
end

# Configure the client with the proper KEY/SECRET, you can create a new one from:
# https://www.bitfinex.com/api
config_file = File.join(File.dirname(__FILE__), 'etc', 'config.yml')
unless File.exist?(config_file)
  puts "You must first add #{config_file}"
  exit 2
end

Currencies = [ 'USD', 'BTC', 'BFX']
Wallets = ['trading', 'exchange', 'deposit']

Config= YAML.load_file(config_file)
Config['websocket_api_endpoint'] ||= 'wss://api.bitfinex.com/ws'
Bitfinex::Client.configure do |conf|
  conf.api_key = Config['api_key']
  conf.secret  = Config['secret']
  conf.websocket_api_endpoint = Config['websocket_api_endpoint']
end


def create_csv_history(wallet = 'trading', currency = 'USD')
  client = Bitfinex::Client.new
  history = []
  timestamp = Time.now.to_i + 1
  while true
    begin
      partial = client.history(currency, { :limit => 500, :until => timestamp, :wallet => wallet})
      break unless partial && partial.size > 0
      if partial.is_a?(Hash)
        puts "Got #{partial['error']} while fetching #{wallet} #{currency} until #{Time.at(timestamp)}"
        exit 3
      end
      first_time = Time.at(partial.first['timestamp'].to_i).strftime('%Y.%m.%d %H:%M:%S')
      last_time = Time.at(partial.last['timestamp'].to_i).strftime('%Y.%m.%d %H:%M:%S')
      puts "Feched #{partial.size} history entries #{first_time} -> #{last_time}"  if $VERBOSE
      timestamp = (partial.last['timestamp'].to_i - 1)
      history = history | partial
      break if partial.size <= 1
    rescue => error
      puts "error #{error}"
    end
  end

  puts "Feched #{history.size} history entries" if $VERBOSE

  CSV.open("#{wallet}_#{currency}.csv",'w',
      :write_headers=> true,
      :headers => ['currency',
                  'amount',
                  'balance',
                  'description',
                  'date_time',
                  ] #< column header
    ) do |csv|
    history.each do | hist_item|
      csv << [ hist_item['currency'],
              hist_item['amount'],
              hist_item['balance'],
              hist_item['description'],
                Time.at(hist_item['timestamp'].to_i).strftime('%Y.%m.%d %H:%M:%S'),
              ]
    end
  end

  sums = {}
  history.each do | hist_item|
    key = /^[^\d]+/.match(hist_item['description'])[0].chomp
    value = hist_item['amount'].to_f
    if sums[key]
      sums[key] +=  value
    else
      sums[key]  =  value
    end
  end

  puts
  puts "Summary for #{wallet} #{currency} (#{history.size} entries}"
  sums.each do |key, value|
    puts " #{sprintf('%40s', key)} is #{value}"
  end
end

Wallets.each do |wallet|
  Currencies.each do |currency|
    create_csv_history(wallet, currency)
  end
end
