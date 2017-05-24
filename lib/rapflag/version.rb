module RAPFLAG
  @@outputDir = File.join(Dir.pwd, 'output')
  def self.outputDir
    @@outputDir
  end
  Wallets = ['trading', 'exchange', 'deposit']
  VERSION='0.0.9'
end
