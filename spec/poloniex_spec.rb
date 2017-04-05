# encoding: utf-8
require 'spec_helper'
require 'rapflag/poloniex'
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :faraday
end

VCR.eject_cassette # we use insert/eject around each example

describe RAPFLAG::Poloniex do
  TEST_OUTPUT_ROOT = File.expand_path(File.join(__FILE__, '..', '..', 'output/poloniex'))
  Poloniex_CSV_Test_File             = TEST_OUTPUT_ROOT + '/BTC_exchange.csv'
  Poloniex_SUMMARY_EXCHANGE_BTC_File = TEST_OUTPUT_ROOT + '/BTC_exchange_summary.csv'
  Poloniex_SUMMARY_DEPOSIT_BFX_File  = TEST_OUTPUT_ROOT + '/BFX_deposit_summary.csv'

  context 'poloniex' do
    before(:all) do
      # skip("We cannot yet use VCR here. Therefore omitting all spec tests")
      # VCR.use_cassette("poloniex", :record => :new_episodes) do
        FileUtils.rm_f(Poloniex_CSV_Test_File) if File.exist?(Poloniex_CSV_Test_File)
        FileUtils.rm_f(Poloniex_SUMMARY_DEPOSIT_BFX_File) if File.exist?(Poloniex_SUMMARY_DEPOSIT_BFX_File)
        FileUtils.rm_f(Poloniex_SUMMARY_EXCHANGE_BTC_File) if File.exist?(Poloniex_CSV_Test_File)
        expect(File.exist?(Poloniex_CSV_Test_File)).to eql(false)
        @rap = RAPFLAG::Poloniex.new('exchange', 'BTC')
        @rap.fetch_csv_history
        # @rap.create_csv_file
       # end
    end
    context 'history' do
      it 'should have correct currency' do
        expect(@rap.currency).to eql('BTC')
      end
      it 'should have correct size' do
        expect(@rap.history.size).to eql(368)
      end
    end
  end
  context 'poloniex CSV' do
    before(:all) do
      skip("We cannot yet use VCR here. Therefore omitting all spec tests")
    end
    context 'csv' do
      it 'should have generated a correct CSV file' do
        expect(File.exist?(Poloniex_CSV_Test_File)).to eql(true)
        lines = IO.readlines(Poloniex_CSV_Test_File)
        expect(lines.first.chomp).to eql('currency,amount,balance,description,date_time')
        expect(lines[1].chomp).to eql(
          'BTC,-0.00000005,0.0,Transfer of 0.0 BTC from wallet Exchange to Deposit on wallet Exchange,2016.12.03 21:20:47')
      end
    end
  end
  context 'exchange option --clean' do
    before(:all) do
      skip("We cannot yet use VCR here. Therefore omitting all spec tests")
      @date_bfx_1 = Date.new(2017,1,10)
      @date_btx_1 = Date.new(2017,1,21)
      @date_btx_2 = Date.new(2017,1,10)
      VCR.use_cassette("poloniex", :record => :new_episodes) do
        FileUtils.rm_f(Poloniex_SUMMARY_EXCHANGE_BTC_File) if File.exist?(Poloniex_CSV_Test_File)
        expect(File.exist?(Poloniex_SUMMARY_EXCHANGE_BTC_File)).to eql(false)
        @exchange = RAPFLAG::Poloniex.new('exchange', 'BTC')
        @exchange.fetch_csv_history
        @exchange.create_summary
        @bfx   = @exchange.get_usd_exchange(@date_bfx_1, 'BFX')
        @btx_1 = @exchange.get_usd_exchange(@date_btx_1, 'BTC')
        @btx_2 = @exchange.get_usd_exchange(@date_btx_2, 'BTC')
      end
    end
    it 'should have generated a correct summary CSV file' do
      expect(File.exist?(Poloniex_SUMMARY_EXCHANGE_BTC_File)).to eql(true)
      lines = IO.readlines(Poloniex_SUMMARY_EXCHANGE_BTC_File)
      expect(lines.first.chomp).to eql('currency,date,income,balance,rate,balance_in_usd')
      expect(lines[1].chomp).to eql('BTC,2016.01.15,0.0,8.99788147,,')
      expect(lines[-1].chomp).to eql('BTC,2016.12.03,0.0,0.0,765.46,0.0')
    end
    it 'should have NOT have generated a correct summary deposit BFX CSV file' do
      expect(File.exist?(Poloniex_SUMMARY_DEPOSIT_BFX_File)).to eql(false)
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
      skip("We cannot yet use VCR here. Therefore omitting all spec tests")
      FileUtils.rm_f(Poloniex_SUMMARY_EXCHANGE_BTC_File) if File.exist?(Poloniex_SUMMARY_EXCHANGE_BTC_File)
      FileUtils.rm_f(Poloniex_SUMMARY_DEPOSIT_BFX_File) if File.exist?(Poloniex_CSV_Test_File)
      @date_bfx_1 = Date.new(2017,1,10)
      @date_btx_1 = Date.new(2017,1,21)
      @date_btx_2 = Date.new(2017,1,10)
      VCR.use_cassette("rapflag", :record => :new_episodes) do
        expect(File.exist?(Poloniex_SUMMARY_DEPOSIT_BFX_File)).to eql(false)
        @deposit = RAPFLAG::Poloniex.new('deposit', 'BFX')
        @deposit.fetch_csv_history
        @deposit.create_summary
      end
    end
    it 'should have NOT generated a exchange BTC summary CSV file' do
      expect(File.exist?(Poloniex_SUMMARY_EXCHANGE_BTC_File)).to eql(false)
    end
    it 'should have NOT generated a correct summary CSV file' do
      expect(File.exist?(Poloniex_SUMMARY_DEPOSIT_BFX_File)).to eql(true)
      lines = IO.readlines(Poloniex_SUMMARY_DEPOSIT_BFX_File)
      expect(lines.first.chomp).to eql('currency,date,income,balance,rate,balance_in_usd')
      expect(lines[1].chomp).to eql('BFX,2016.01.15,0.0,8.99788147,,')
    end
  end
end
