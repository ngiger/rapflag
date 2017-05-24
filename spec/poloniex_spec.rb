# encoding: utf-8
require 'spec_helper'
require 'rapflag/poloniex'

describe RAPFLAG::Poloniex do
  Poloniex_CSV_Test_Lending_File     = File.join(RAPFLAG.outputDir, 'poloniex', 'lending_BTC.csv')
  Poloniex_CSV_Test_Exchange_File    = File.join(RAPFLAG.outputDir, 'poloniex', 'exchange_BTC.csv')

  context 'poloniex' do
    before(:all) do
      FileUtils.rm_rf(RAPFLAG.outputDir)
      expect(File.exist?(Poloniex_CSV_Test_Lending_File)).to eql(false)
      @rap = RAPFLAG::Poloniex.new('exchange', 'BTC')
      @rap.fetch_csv_history
    end
    context 'history' do
      it 'should have correct trades' do
        expect(@rap.currency).to eql('BTC')
        expect(File.exist?(Poloniex_CSV_Test_Lending_File)).to eql(true)
        lines = IO.readlines(Poloniex_CSV_Test_Lending_File)
        expect(lines.first.chomp).to eql('current_day;balance_BEG;deposits;income;withdraw;sales;purchases;balance_END;fees;day_difference')

        first_trade = lines.find{|line| /2017-03-25/.match(line)}.chomp
        day_difference = first_trade.split(';')[-1]
        expect(day_difference.to_f).to eql(-0.9895374700000007)

        second_trade = lines.find{|line| /2017-03-24/.match(line)}.chomp
        day_difference = second_trade.split(';')[-1]
        expect(day_difference.to_f).to eql(-3.6381863327881176)

        third_trade = lines.find{|line| /2016-06-17/.match(line)}.chomp
        day_difference = third_trade.split(';')[-1]
        expect(day_difference.to_f).to eql(7.177347194443261)
        income1 = first_trade.split(';')[3]
        expect(income1.to_f).to eql(0.01046259)
        income2 = second_trade.split(';')[3]
        expect(income2.to_f).to eql(0.03696987000000001)
      end
      it 'should have correct size' do
        expect(@rap.history.size).to eql(368)
      end
    end
  end
end
