# encoding: utf-8
require 'spec_helper'
require 'rapflag/fetch'
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :faraday # or :fakeweb
end

TestFile = File.expand_path(File.join(__FILE__, '..', '..', 'output/exchange_BTC.csv'))
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
        FileUtils.rm_f(TestFile) if File.exist?(TestFile)
        expect(File.exist?(TestFile)).to eql(false)
        @rap = RAPFLAG::History.new('exchange', 'BTC')
        @rap.fectch_csv_history
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
      it 'should have correct currency' do
        expect(File.exist?(TestFile)).to eql(true)
      end
    end
  end
end