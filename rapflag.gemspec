# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rapflag/version'

Gem::Specification.new do |spec|
  spec.name        = "rapflag"
  spec.version     = RAPFLAG::VERSION
  spec.author      = "Zeno R.R. Davatz, Niklaus Giger"
  spec.email       = "zdavatz@ywesee.com, ngiger@ywesee.com"
  spec.description = "Bitfinex Exporter for your Taxman"
  spec.summary     = "Bitfinex Exporter for your Taxman from ywesee"
  spec.homepage    = "https://github.com/zdavatz/rapflag"
  spec.license       = "GPL-v2"
  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'bitfinex-rb'
  spec.add_dependency 'trollop'

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "pry-byebug"
end

