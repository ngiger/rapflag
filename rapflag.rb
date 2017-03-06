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


Config= YAML.load_file(config_file)
Config['websocket_api_endpoint'] ||= 'wss://api.bitfinex.com/ws'
Bitfinex::Client.configure do |conf|
  conf.api_key = Config['api_key']
  conf.secret  = Config['secret']
  conf.websocket_api_endpoint = Config['websocket_api_endpoint']
end

client = Bitfinex::Client.new
history = []
timestamp = Time.now.to_i + 1
while true
  partial = client.history('USD', { :limit => 500, :until => timestamp })
  first_time = Time.at(partial.first['timestamp'].to_i).strftime('%Y.%m.%d %H:%M:%S')
  last_time = Time.at(partial.last['timestamp'].to_i).strftime('%Y.%m.%d %H:%M:%S')
  puts "Feched #{partial.size} history entries #{first_time} -> #{last_time}"
  timestamp = partial.last['timestamp'].to_i
  history = history | partial
  break if partial.size <= 1
end

puts "Feched #{history.size} history entries"

CSV.open('output.csv','w',
    :write_headers=> true,
    :headers => ["currency","amount","amount", 'description','date_time'
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