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
  if defined?(RSpec)
    Config = Hash.new
  else
    unless config_file && File.exist?(config_file)
      puts "You must first add a config.yml. Use one of the following places #{files_to_test}"
      exit 2
    end

    Config= YAML.load_file(config_file)
  end
  Config['currencies'] ||= ['BTC', 'BFX', 'XMR', 'ZEC', 'XRP', 'ETH']
  Config['currencies'] << 'USD' unless Config['currencies'].index('USD')
  Config['currencies'].sort!
end
