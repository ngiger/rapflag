# encoding: utf-8
require 'spec_helper'
require 'rapflag/fetch'
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :faraday # or :fakeweb
end

CSV_Test_File = File.expand_path(File.join(__FILE__, '..', '..', 'output/exchange_BTC.csv'))
SUMMARY_Test_File = File.expand_path(File.join(__FILE__, '..', '..', 'output/exchange_BTC_summary.csv'))

VCR.eject_cassette # we use insert/eject around each example
describe RAPFLAG do
  # include ServerMockHelper
  before(:all) do
  end
  after(:all) do
  end
  context 'bitfinex' do
    before(:all) do
      VCR.use_cassette("rapflag") do
        FileUtils.rm_f(CSV_Test_File) if File.exist?(CSV_Test_File)
        FileUtils.rm_f(SUMMARY_Test_File) if File.exist?(CSV_Test_File)
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
  context 'option --clean' do
    before(:all) do
      VCR.use_cassette("rapflag") do
        FileUtils.rm_f(SUMMARY_Test_File) if File.exist?(CSV_Test_File)
        expect(File.exist?(SUMMARY_Test_File)).to eql(false)
        @rap = RAPFLAG::History.new('exchange', 'BTC')
        @rap.fetch_csv_history
        @rap.create_summary
      end
    end
    context 'csv' do
      it 'should have generated a correct summary CSV file' do
        expect(File.exist?(SUMMARY_Test_File)).to eql(true)
        lines = IO.readlines(SUMMARY_Test_File)
        expect(lines.first.chomp).to eql('currency,date,income,balance')
        expect(lines[1].chomp).to eql('BTC,2016.01.15,0.0,8.99788147')
# BTC -8.99788147 0 Exchange 8.99788147 BTC for USD @ 405.47 on wallet Exchange 2016.01.15 13:12:25
# BTC -0.57652249 8.99788147  Exchange 0.57652249 BTC for USD @ 405.47 on wallet Exchange 2016.01.15 13:12:06
# BTC -0.07206527 9.57440396  Exchange 0.07206527 BTC for USD @ 405.47 on wallet Exchange 2016.01.15 13:12:05
# BTC -1.9318 9.64646923  Exchange 1.9318 BTC for USD @ 405.47 on wallet Exchange 2016.01.15 13:11:33
# BTC 11.57826923 11.57826923 Transfer of 11.5783 BTC from wallet Deposit to Exchange on wallet Exchange  2016.01.15 13:10:06
# BTC -12.65  0 Exchange 12.65 BTC for USD @ 403.67 on wallet Exchange  2016.01.15 13:00:09
# BTC 12.65 12.65 Transfer of 12.65 BTC from wallet Trading to Exchange on wallet Exchange  2016.01.15 12:59:41
      end
    end
  end
end