# rapflag
Bitfinex Exporter for your Taxman.

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
### run as follows
```
ruby rapflag.rb
ruby rapflag.rb -c (clean option to show daily income and daily value of your wallet)
```
Enjoy your reports. More to come. Feedback always welcome.

### License
GPLv3.0, see License File.
