require 'bitfinex-api-rb'

# Configure the client with the proper KEY/SECRET, you can create a new one from:
# https://www.bitfinex.com/api
Bitfinex::Client.configure do |conf|
  conf.api_key = ""
  conf.secret  = ""
  conf.websocket_api_endpoint = "wss://api.bitfinex.com/ws"
end

client = Bitfinex::Client.new
client.history
puts client.history
