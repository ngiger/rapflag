# encoding: utf-8
require 'spec_helper'
require 'rapflag/bitfinex'
require 'vcr'
require 'date'

VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :faraday # or :fakeweb
end

VCR.eject_cassette # we use insert/eject around each example
def gen_deposit
  @date_bfx_1 = Date.new(2017,1,10)
  @date_btx_1 = Date.new(2017,1,21)
  @date_btx_2 = Date.new(2017,1,10)
  VCR.use_cassette("rapflag", :record => :new_episodes) do
    expect(File.exist?(BITFINEX_SUMMARY_DEPOSIT_BFX_File)).to eql(false)
    @deposit = RAPFLAG::Bitfinex.new('deposit', 'BFX')
    @deposit.fetch_csv_history
    @deposit.create_summary
  end
end
def gen_exchange
  @date_bfx_1 = Date.new(2017,1,10)
  @date_btx_1 = Date.new(2017,1,21)
  @date_btx_2 = Date.new(2017,1,10)
  VCR.use_cassette("rapflag", :record => :new_episodes) do
    expect(File.exist?(BITFINEX_SUMMARY_EXCHANGE_BTC_File)).to eql(false)
    @exchange = RAPFLAG::Bitfinex.new('exchange', 'BTC')
    @exchange.fetch_csv_history
    @exchange.create_summary
  end
end
def gen_dump(wallet = 'deposit')
  @date_bfx_1 = Date.new(2017,1,10)
  @date_btx_1 = Date.new(2017,1,21)
  @date_btx_2 = Date.new(2017,1,10)
  VCR.use_cassette("btc_#{wallet}", :record => :new_episodes) do
    @history_name = File.join(RAPFLAG.outputDir, 'bitfinex', "BTC_#{wallet}_history.csv")
    expect(File.exist?(@history_name)).to eql(false)
    @exchange = RAPFLAG::Bitfinex.new(wallet, 'BTC')
    @exchange.fetch_csv_history
    @exchange.dump_history
    @exchange.create_summary
    @exchange.create_total
  end
end
describe RAPFLAG::Bitfinex do
  OUTPUT_ROOT = File.expand_path(File.join(__FILE__, '..', 'output'))
  Bitfinex_CSV_Test_File             = File.join(RAPFLAG.outputDir, 'bitfinex', 'BTC_exchange.csv')
  BITFINEX_SUMMARY_DEPOSIT_BFX_File  = File.join(RAPFLAG.outputDir, 'bitfinex', 'BTC_deposit_summary.csv')
  BITFINEX_SUMMARY_EXCHANGE_BTC_File = File.join(RAPFLAG.outputDir, 'bitfinex', 'BTC_exchange_summary.csv')
  BITFINEX_SUMMARY_TRADING_BTC_File  = File.join(RAPFLAG.outputDir, 'bitfinex', 'BTC_trading_summary.csv')
  BITFINEX_TOTAL_BTC_File            = File.join(RAPFLAG.outputDir, 'bitfinex', 'BTC_total.csv')
  BITFINEX_SUMMARY_DEPOSIT_BFX_File  = File.join(RAPFLAG.outputDir, 'bitfinex', 'BFX_deposit_summary.csv')

  # include ServerMockHelper
  before(:all) do
  end
  after(:all) do
  end
  context 'bitfinex' do
    before(:all) do
      FileUtils.rm_rf(RAPFLAG.outputDir)
      VCR.use_cassette("rapflag", :record => :new_episodes) do
        expect(File.exist?(Bitfinex_CSV_Test_File)).to eql(false)
        @rap = RAPFLAG::Bitfinex.new('exchange', 'BTC')
        @rap.fetch_csv_history
        @rap.create_csv_file
      end
    end
    it 'should store into spec/output' do
      expect(OUTPUT_ROOT).to eq RAPFLAG.outputDir
    end
    context 'history' do
      it 'should have correct currency' do
        expect(@rap.currency).to eql('BTC')
      end
      it 'should have correct size' do
        expect(@rap.history.size).to eql(206)
      end
    end
  end
  context 'bitfinex CSV' do
    context 'csv' do
      it 'should have generated a correct CSV file' do
        expect(File.exist?(Bitfinex_CSV_Test_File)).to eql(true)
        lines = IO.readlines(Bitfinex_CSV_Test_File)
        expect(lines.first.chomp).to eql('currency,amount,balance,description,date_time')
        expect(lines[1].chomp).to eql(
          'BTC,-0.00000005,0.0,Transfer of 0.0 BTC from wallet Exchange to Deposit on wallet Exchange,2016.12.03 21:20:47')
      end
      it 'should have some lines inverted if the timestamp match' do
        expect(File.exist?(Bitfinex_CSV_Test_File)).to eql(true)
        lines = IO.readlines(Bitfinex_CSV_Test_File)
        first  = lines.index("BTC,-0.0170128,11.0283072,Trading fees for 8.5064 BTC @ 442.06 on BFX (0.2%) on wallet Exchange,2016.02.21 23:48:48\n")
        second = lines.index("BTC,-0.0004,11.04532,Trading fees for 0.2 BTC @ 442.1 on BFX (0.2%) on wallet Exchange,2016.02.21 23:48:48\n")
        expect(second + 1).to eq first
      end
    end
  end
  context 'exchange option --clean' do
    before(:all) do
      gen_exchange
    end
    it 'should have generated a correct exchange summary CSV file' do
      expect(File.exist?(BITFINEX_SUMMARY_EXCHANGE_BTC_File)).to eql(true)
      lines = IO.readlines(BITFINEX_SUMMARY_EXCHANGE_BTC_File)
      expect(lines.first.chomp).to eql('currency,date,income,balance')
      expect(lines[1].chomp).to eql('BTC,2016.01.15,"",0.0')
      expect(lines[-1].chomp).to eql('BTC,2016.12.03,"",0.0')
    end
    it 'should have a balance for for each day' do
      expect(File.exist?(BITFINEX_SUMMARY_EXCHANGE_BTC_File)).to eql(true)
      lines = IO.readlines(BITFINEX_SUMMARY_EXCHANGE_BTC_File)
      first_date = Date.strptime(lines[1].chomp.split(RAPFLAG::COLUMN_SEPARATOR)[1], '%Y.%m.%d')
      last_date = Date.strptime(lines[-1].chomp.split(RAPFLAG::COLUMN_SEPARATOR)[1], '%Y.%m.%d')
      expect((last_date >  first_date)).to be true
      nr_dates = 323
      expect((last_date -  first_date).to_i).to eql nr_dates
      (1..nr_dates).each do |j|
        wish_date = (first_date + j).strftime('%Y.%m.%d')
        expect(lines.find_all{|line| line.index(wish_date)}.size).to eql 1
      end
    end
    it 'should have NOT have generated a correct summary deposit BFX CSV file' do
      expect(File.exist?(BITFINEX_SUMMARY_DEPOSIT_BFX_File)).to eql(false)
    end
  end
  context 'deposit option --clean' do
    before(:all) do
      FileUtils.rm_rf(RAPFLAG.outputDir)
      gen_deposit
      VCR.use_cassette("rapflag", :record => :new_episodes) do
        @exchange = RAPFLAG::Bitfinex.new('exchange', 'BTC')
        @exchange.fetch_csv_history
        @exchange.create_summary
      end
      VCR.use_cassette("rapflag", :record => :new_episodes) do
        @trading = RAPFLAG::Bitfinex.new('trading', 'BTC')
        @trading.fetch_csv_history
        @trading.create_summary
      end
      @trading.create_total
    end
    it 'should have generated a exchange BTC summary CSV file' do
      expect(File.exist?(BITFINEX_SUMMARY_EXCHANGE_BTC_File)).to eql(true)
    end
    it 'should have generated a trading BTC summary CSV file' do
      expect(File.exist?(BITFINEX_SUMMARY_TRADING_BTC_File)).to eql(true)
    end
    it 'should have generated a deposit BTC summary CSV file' do
      expect(File.exist?(BITFINEX_SUMMARY_DEPOSIT_BFX_File)).to eql(true)
    end
    it 'should generate a correct summary CSV file' do
      expect(File.exist?(BITFINEX_SUMMARY_DEPOSIT_BFX_File)).to eql(true)
      lines = IO.readlines(BITFINEX_SUMMARY_DEPOSIT_BFX_File)
      expect(lines.first.chomp).to eql('currency,date,income,balance')
      expect(lines[1].chomp).to eql('BFX,2016.01.15,"",0.0')
    end
  end
  context 'option --dump' do
    before(:all) do
      FileUtils.rm_rf(RAPFLAG.outputDir)
      RAPFLAG::Wallets.each{ |wallet| gen_dump(wallet) }
      @stichtag = '2017.05.23'
    end
    it 'should have generated a correct deposit history CSV file' do
      history_name = File.join(RAPFLAG.outputDir, 'bitfinex', "BTC_deposit_history.csv")
      expect(File.exist?(history_name)).to eql(true)
      lines = IO.readlines(history_name)
      expect(lines.first.chomp).to eql('currency,amount,balance,description,timestamp,date')
      expect(lines[1].chomp).to eql('BTC,0.00000183,26.23947379,Margin Funding Payment on wallet Deposit,1500773485.0,2017.07.23')
      expect(lines[-1].chomp).to eql('BTC,2.0,2.0,Deposit (BITCOIN) #614485 on wallet Deposit,1446157557.0,2015.10.29')
      stich_item = lines.find{|x| /#{@stichtag}/.match(x)}.chomp
      expect(stich_item).to eql 'BTC,-1.10078339,41.64921661,Transfer of 1.1008 BTC from wallet Deposit to Exchange on wallet Deposit,1495556898.0,2017.05.23'
    end
    it 'should have generated a correct exchange history CSV file' do
      history_name = File.join(RAPFLAG.outputDir, 'bitfinex', "BTC_exchange_history.csv")
      expect(File.exist?(history_name)).to eql(true)
      lines = IO.readlines(history_name)
      expect(lines.first.chomp).to eql('currency,amount,balance,description,timestamp,date')
      expect(lines[1].chomp).to eql('BTC,-2.9,0.0,Transfer of 2.9 BTC from wallet Exchange to Deposit on wallet Exchange,1497288653.0,2017.06.12')
      expect(lines[-1].chomp).to eql('BTC,12.65,12.65,Transfer of 12.65 BTC from wallet Trading to Exchange on wallet Exchange,1452859181.0,2016.01.15')
      stich_item = lines.find{|x| /#{@stichtag}/.match(x)}.chomp
      expect(stich_item).to eql 'BTC,-0.98257955,0.0,Exchange 0.98257955 BTC for USD @ 2220.8 on wallet Exchange,1495557186.0,2017.05.23'
    end
    it 'should have generated a correct trading history CSV file' do
      history_name = File.join(RAPFLAG.outputDir, 'bitfinex', "BTC_trading_history.csv")
      expect(File.exist?(history_name)).to eql(true)
      lines = IO.readlines(history_name)
      expect(lines.first.chomp).to eql('currency,amount,balance,description,timestamp,date')
      expect(lines[1].chomp).to eql('BTC,-12.65,0.0,Transfer of 12.65 BTC from wallet Trading to Exchange on wallet Trading,1452859181.0,2016.01.15')
      expect(lines[-1].chomp).to eql('BTC,12.65,12.65,Transfer of 12.65 BTC from wallet Deposit to Trading on wallet Trading,1452859061.0,2016.01.15')
      expect(lines.find{|x| /#{@stichtag}/.match(x)}).to eql nil
    end
    it 'should have generated a correct total CSV file' do
      total_name = File.join(RAPFLAG.outputDir, 'bitfinex', "BTC_total.csv")
      expect(File.exist?(total_name)).to eql(true)
      lines = IO.readlines(total_name)
      expect(lines.first.chomp).to eql('currency,date,total_income,total_balance')
      expect(lines[1].chomp).to eql('BTC,2015.10.29,0.0,2.0')
      expect(lines[-1].chomp).to eql('BTC,2017.07.23,1.83e-06,26.23947379')

      # If no trades were given we must repeat the amount for each day
      first_date = lines.find_all{ |x| /BTC,2016.07.01/.match(x)}[0]
      amounts = /BTC,2016.07.01,(.*)/.match(first_date)[1]
      all_days = lines.find_all{ |x| x.index(amounts) }
      expect(all_days = lines.find_all{ |x| x.index(amounts) }.size).to be > 1
      stich_item = lines.find{|x| /#{@stichtag}/.match(x)}.chomp
      expect(stich_item).to eql 'BTC,2017.05.23,0.030693480000000002,41.64921661'
    end
  end
end
