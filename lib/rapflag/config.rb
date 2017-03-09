require 'yaml'
require 'bitfinex-api-rb'

module RAPFLAG

  # Configure the client with the proper KEY/SECRET, you can create a new one from:
  # https://www.bitfinex.com/api
  config_file = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'etc', 'config.yml'))
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
end
