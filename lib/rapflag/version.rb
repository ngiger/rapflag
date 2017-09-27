module RAPFLAG
  @@outputDir = File.join(Dir.pwd, 'output')
  def self.outputDir
    @@outputDir
  end
  Wallets = ['trading', 'exchange', 'deposit']
  COLUMN_SEPARATOR = ','
  VERSION='1.0.6'
end
