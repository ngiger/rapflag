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
    @bfx   = @exchange.get_usd_exchange(@date_bfx_1, 'BFX')
    @btx_1 = @exchange.get_usd_exchange(@date_btx_1, 'BTC')
    @btx_2 = @exchange.get_usd_exchange(@date_btx_2, 'BTC')
  end
end
def gen_trading
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
    end
  end
  context 'exchange option --clean' do
    before(:all) do
      gen_exchange
    end
    it 'should have generated a correct summary CSV file' do
      expect(File.exist?(BITFINEX_SUMMARY_EXCHANGE_BTC_File)).to eql(true)
      lines = IO.readlines(BITFINEX_SUMMARY_EXCHANGE_BTC_File)
      expect(lines.first.chomp).to eql('currency,date,income,balance,rate,balance_in_usd')
      expect(lines[1].chomp).to eql('BTC,2016.01.15,0.0,8.99788147,,')
      expect(lines[-1].chomp).to eql('BTC,2016.12.03,0.0,0.0,765.46,0.0')
    end
    it 'should have a balance for for each day' do
      expect(File.exist?(BITFINEX_SUMMARY_EXCHANGE_BTC_File)).to eql(true)
      lines = IO.readlines(BITFINEX_SUMMARY_EXCHANGE_BTC_File)
      first_date = Date.strptime(lines[1].chomp.split(RAPFLAG::COLUMN_SEPARATOR)[1], '%Y.%m.%d')
      last_date = Date.strptime(lines[-1].chomp.split(RAPFLAG::COLUMN_SEPARATOR)[1], '%Y.%m.%d')
      (last_date >  first_date).should be true
      nr_dates = 323
      (last_date -  first_date).to_i.should eql nr_dates
      (1..nr_dates).each do |j|
        wish_date = (first_date + j).strftime('%Y.%m.%d')
        lines.find_all{|line| line.index(wish_date)}.size.should eql 1
      end
    end
    it 'should have NOT have generated a correct summary deposit BFX CSV file' do
      expect(File.exist?(BITFINEX_SUMMARY_DEPOSIT_BFX_File)).to eql(false)
    end
    it 'should have the correct BTC -> USD rate' do
      expect(@btx_1).to eql 924.02
      expect(@btx_2).to eql 905.76
    end
    it 'should have the correct BFX -> USD rate' do
      expect(@bfx).to eql 0.5697
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
        @bfx   = @exchange.get_usd_exchange(@date_bfx_1, 'BFX')
        @btx_1 = @exchange.get_usd_exchange(@date_btx_1, 'BTC')
        @btx_2 = @exchange.get_usd_exchange(@date_btx_2, 'BTC')
      end
      VCR.use_cassette("rapflag", :record => :new_episodes) do
        @trading = RAPFLAG::Bitfinex.new('trading', 'BTC')
        @trading.fetch_csv_history
        @trading.create_summary
        @bfx   = @trading.get_usd_exchange(@date_bfx_1, 'BFX')
        @btx_1 = @trading.get_usd_exchange(@date_btx_1, 'BTC')
        @btx_2 = @trading.get_usd_exchange(@date_btx_2, 'BTC')
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
      expect(lines.first.chomp).to eql('currency,date,income,balance,rate,balance_in_usd')
      expect(lines[1].chomp).to eql('BFX,2016.01.15,0.0,8.99788147,,')
    end
    it 'should generate a correct BTX_total file' do
      expect(File.exist?(BITFINEX_TOTAL_BTC_File)).to eql(true)
      lines = IO.readlines(BITFINEX_TOTAL_BTC_File)
      expect(lines.first).not_to be_nil
      expect(lines.first.chomp).to eql('currency,date,total_income,total_balance')
      expect(lines[1].chomp).to eql('BTC,2016.01.15,0.0,134.96822204999995')
      expect(lines[4].chomp).to eql('BTC,2016.02.14,-0.11651520000000001,58.1410848')
    end
  end
end
