# rapflag
Bitfinex and Poloniex Exporter for your Taxman.

### example installation instructions
```
yum install ruby-devel gcc-c++ make
gem install public_suffix:2.0.5 rapflag
```

### set your keys, desired currencies in
```
 ./etc/config.yml
```
sample
```
currencies: [ 'USD', 'BTC', 'BFX']
api_key: ''
secret: ''
poloniex_api_key: ''
poloniex_secret: ''
```
comment out "currencies" if you want to export all currencies.
### run as follows
```
Options:
  -c, --clean       Create Bitfinex summary of transactions by day
  -p, --poloniex    Use Poloniex API instead of Bitfinex API
  -d, --dump        Use Poloniex API and dump history into CSV files
  -h, --help        Show this message
```
Enjoy your reports. More to come. Feedback always welcome.

### License
GPLv3.0, see License File.
