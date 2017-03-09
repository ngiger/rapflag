#!/usr/bin/env ruby
require 'rapflag/version'
require 'rapflag/config'
require 'rapflag/fetch'
require 'trollop'

begin
require 'pry'
rescue LOAD_ERROR
end

Opts = Trollop::options do
  opt :clean, "Create summary of transactions by day"
end

RAPFLAG::Wallets.each do |wallet|
  RAPFLAG::Currencies.each do |currency|
    rap = RAPFLAG::History.new(wallet, currency)
    rap.fetch_csv_history
    rap.create_csv_file
    rap.create_summary if Opts[:clean]
  end
end
