# 1.0.3 of 2017.07.26

* <ticker>_total has balance + sum of balance fields of [deposit,trading,exchange]
* Added spec test for BTC. Checks balance of 2017.05.23

# 1.0.2 of 2017.07.26

* Correct calculation of balance for total files. 
* Consider settlement as income
* Correct calculation of balance for total files. Consider settlement (for dump)
* Remove empty test target
* Implemented dump_history also for bitfinex


# 1.0.1 of 2017.07.26

* Create correct entries for intermediate dates

# 1.0.0 of 2017.05.28

* Handle two transactions with same timestamp
* Fix duplicated income
* Do not emit rate and balance_in_usd for bitfinex
* Use ',' as column separator.

# 0.0.9 of 2017.05.24

* Add <currency>_total files for bitfinex

# 0.0.8 of 2017.04.17

* Wait (possibly several times) when we hit the rate limiter of the bitfinex REST API while fetching the currency rates

# 0.0.7 of 2017.04.17

* Wait (possibly several times) when we hit the rate limiter of the bitfinex REST API while fetching the histor

# 0.0.6 of 2017.04.11

* Download complete lending history not only he default of 500 items

# 0.0.5 of 2017.04.10

* Fixed daily balance for poloniex

# 0.0.4 of 2017.04.05

* Added options -p and -d for Poloniex
* Fixed problem with inexisting spec/data/*.json files

# 0.0.3 of 2017.04.02

* Output files start with the currency name


