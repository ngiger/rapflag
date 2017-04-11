# rapflag
Bitfinex and Poloniex Exporter for your Taxman.

### set your key, desired currencies in
```
 ./etc/config.yml
```
sample
```
---
currencies: [ 'USD', 'BTC', 'BFX']
api_key: ''
secret: ''
```
comment out "currencies" if you want to export all currencies.
### run as follows
```
rapflag
rapflag -c (clean option to show daily income and daily value of your wallet)
rapflag -p
```
Enjoy your reports. More to come. Feedback always welcome.

### License
GPLv3.0, see License File.
