#!/usr/bin/env ruby
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rapflag/version'
require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)
# encoding: utf-8

desc 'Offer a gem task like hoe'
task :gem => :build do
  Rake::Task[:build].invoke
end

task :spec => :clean
task :default => [:clean, :spec, :gem]

require 'rake/clean'
CLEAN.include FileList['pkg/**']
CLEAN.include FileList['data/download']
