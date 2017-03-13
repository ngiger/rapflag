# encoding: utf-8
require 'spec_helper'
require 'rapflag/fetch'
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :faraday # or :fakeweb
end

CSV_Test_File = File.expand_path(File.join(__FILE__, '..', '..', 'output/exchange_BTC.csv'))
SUMMARY_EXCHANGE_BTC_File = File.expand_path(File.join(__FILE__, '..', '..', 'output/exchange_BTC_summary.csv'))
SUMMARY_DEPOSIT_BFX_File = File.expand_path(File.join(__FILE__, '..', '..', 'output/deposit_BFX_summary.csv'))

VCR.eject_cassette # we use insert/eject around each example
describe RAPFLAG do
  # include ServerMockHelper
  before(:all) do
  end
  after(:all) do
  end
  context 'bitfinex' do
    before(:all) do
      VCR.use_cassette("rapflag", :record => :new_episodes) do
        FileUtils.rm_f(CSV_Test_File) if File.exist?(CSV_Test_File)
        FileUtils.rm_f(SUMMARY_DEPOSIT_BFX_File) if File.exist?(SUMMARY_DEPOSIT_BFX_File)
        FileUtils.rm_f(SUMMARY_EXCHANGE_BTC_File) if File.exist?(CSV_Test_File)
        expect(File.exist?(CSV_Test_File)).to eql(false)
        @rap = RAPFLAG::History.new('exchange', 'BTC')
        @rap.fetch_csv_history
        @rap.create_csv_file
      end
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
        expect(File.exist?(CSV_Test_File)).to eql(true)
        lines = IO.readlines(CSV_Test_File)
        expect(lines.first.chomp).to eql('currency,amount,balance,description,date_time')
        expect(lines[1].chomp).to eql(
          'BTC,-0.00000005,0.0,Transfer of 0.0 BTC from wallet Exchange to Deposit on wallet Exchange,2016.12.03 21:20:47')
      end
    end
  end
  context 'exchange option --clean' do
    before(:all) do
      @date_bfx_1 = Date.new(2017,1,10)
      @date_btx_1 = Date.new(2017,1,21)
      @date_btx_2 = Date.new(2017,1,10)
      VCR.use_cassette("rapflag", :record => :new_episodes) do
        FileUtils.rm_f(SUMMARY_EXCHANGE_BTC_File) if File.exist?(CSV_Test_File)
        expect(File.exist?(SUMMARY_EXCHANGE_BTC_File)).to eql(false)
        @exchange = RAPFLAG::History.new('exchange', 'BTC')
        @exchange.fetch_csv_history
        @exchange.create_summary
        @bfx   = @exchange.get_usd_exchange(@date_bfx_1, 'BFX')
        @btx_1 = @exchange.get_usd_exchange(@date_btx_1, 'BTC')
        @btx_2 = @exchange.get_usd_exchange(@date_btx_2, 'BTC')
      end
    end
    it 'should have generated a correct summary CSV file' do
      expect(File.exist?(SUMMARY_EXCHANGE_BTC_File)).to eql(true)
      lines = IO.readlines(SUMMARY_EXCHANGE_BTC_File)
      expect(lines.first.chomp).to eql('currency,date,income,balance,rate,balance_in_usd')
      expect(lines[1].chomp).to eql('BTC,2016.01.15,0.0,8.99788147,,')
      expect(lines[-1].chomp).to eql('BTC,2016.12.03,0.0,0.0,765.46,0.0')
    end
    it 'should have NOT have generated a correct summary deposit BFX CSV file' do
      expect(File.exist?(SUMMARY_DEPOSIT_BFX_File)).to eql(false)
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
      FileUtils.rm_f(SUMMARY_EXCHANGE_BTC_File) if File.exist?(SUMMARY_EXCHANGE_BTC_File)
      FileUtils.rm_f(SUMMARY_DEPOSIT_BFX_File) if File.exist?(CSV_Test_File)
      @date_bfx_1 = Date.new(2017,1,10)
      @date_btx_1 = Date.new(2017,1,21)
      @date_btx_2 = Date.new(2017,1,10)
      VCR.use_cassette("rapflag", :record => :new_episodes) do
        expect(File.exist?(SUMMARY_DEPOSIT_BFX_File)).to eql(false)
        @deposit = RAPFLAG::History.new('deposit', 'BFX')
        @deposit.fetch_csv_history
        @deposit.create_summary
      end
    end
    it 'should have NOT generated a exchange BTC summary CSV file' do
      expect(File.exist?(SUMMARY_EXCHANGE_BTC_File)).to eql(false)
    end
    it 'should have NOT generated a correct summary CSV file' do
      expect(File.exist?(SUMMARY_DEPOSIT_BFX_File)).to eql(true)
      lines = IO.readlines(SUMMARY_DEPOSIT_BFX_File)
      expect(lines.first.chomp).to eql('currency,date,income,balance,rate,balance_in_usd')
      expect(lines[1].chomp).to eql('BFX,2016.01.15,0.0,8.99788147,,')
    end
  end
end
# https://api.bitfinex.com/v2/candles/trade:1D:tBTCUSD/hist
# [[1489363200000,1224.4,1211.2,1238,1206.7,6157.96283895],
#  [1489276800000,1172.5,1224.4,1232.7,1166.8,18976.8181757]