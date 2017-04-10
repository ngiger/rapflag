# encoding: utf-8
require 'spec_helper'
require 'rapflag/poloniex'

describe RAPFLAG::Poloniex do
  TEST_OUTPUT_ROOT = File.expand_path(File.join(__FILE__, '..', '..', 'output/poloniex'))
  Poloniex_CSV_Test_Lending_File     = TEST_OUTPUT_ROOT + '/lending_BTC.csv'
  Poloniex_CSV_Test_Exchange_File    = TEST_OUTPUT_ROOT + '/exchange_BTC.csv'

  context 'poloniex' do
    before(:all) do
      FileUtils.rm_f(Poloniex_CSV_Test_Lending_File) if File.exist?(Poloniex_CSV_Test_Lending_File)
      FileUtils.rm_f(Poloniex_CSV_Test_Exchange_File) if File.exist?(Poloniex_CSV_Test_Exchange_File)
      expect(File.exist?(Poloniex_CSV_Test_Lending_File)).to eql(false)
      @rap = RAPFLAG::Poloniex.new('exchange', 'BTC')
      @rap.fetch_csv_history
    end
    context 'history' do
      it 'should have correct trades' do
        expect(@rap.currency).to eql('BTC')
        expect(File.exist?(Poloniex_CSV_Test_Lending_File)).to eql(true)
        lines = IO.readlines(Poloniex_CSV_Test_Lending_File)
        expect(lines.first.chomp).to eql('current_day;current_balance;deposits;withdrawals;earned;fees;sales;purchases;day_difference')
        first_trade = lines.find{|line| /2017-03-25/.match(line)}.chomp
        day_difference = first_trade.split(';')[-1]
        expect(day_difference.to_f).to eql(-1.0018463600000007)
        second_trade = lines.find{|line| /2017-03-24/.match(line)}.chomp
        day_difference = second_trade.split(';')[-1]
        expect(day_difference.to_f).to eql(-3.6816801927881175)
      end
      it 'should have correct size' do
        expect(@rap.history.size).to eql(368)
      end
    end
  end
end
