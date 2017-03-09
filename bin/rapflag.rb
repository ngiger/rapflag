#!/usr/bin/env ruby
require 'rapflag/version'
require 'rapflag/config'
require 'rapflag/fetch'

begin
require 'pry'
rescue LOAD_ERROR
end

RAPFLAG::Wallets.each do |wallet|
  RAPFLAG::Currencies.each do |currency|
    rap = RAPFLAG::History.new(wallet, currency)
    rap.fectch_csv_history
    rap.create_csv_file
  end
end
