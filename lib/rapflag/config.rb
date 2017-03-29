require 'yaml'
require 'bitfinex-api-rb'

module RAPFLAG

  # Configure the client with the proper KEY/SECRET, you can create a new one from:
  # https://www.bitfinex.com/api
  config_file = nil
  files_to_test =  [ File.join(Dir.pwd, 'etc', 'config.yml'),
                     File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'etc', 'config.yml'))
                   ]
  files_to_test.each do |file_to_check|
    if File.exist?(file_to_check)
      config_file = file_to_check
      puts "Using config from #{file_to_check}"
      break
    end
  end
  unless config_file && File.exist?(config_file)
    puts "You must first add. Use one of the following places #{files_to_test}"
    exit 2
  end

  Config= YAML.load_file(config_file)
  Config['websocket_api_endpoint'] ||= 'wss://api.bitfinex.com/ws'
  Config['currencies'] ||= ['BTC BFX XMR ZEC']
  Config['currencies'] << 'USD' unless Config['currencies'].index('USD')
  Bitfinex::Client.configure do |conf|
    conf.api_key = Config['api_key']
    conf.secret  = Config['secret']
    conf.websocket_api_endpoint = Config['websocket_api_endpoint']
  end
end
