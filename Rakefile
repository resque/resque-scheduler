# vim:fileencoding=utf-8
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'yard'

task default: :test

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = ENV['PATTERN'] || 'test/*_test.rb'
  t.options = ''.tap do |o|
    o << "--seed #{ENV['SEED']} " if ENV['SEED']
    o << '--verbose ' if ENV['VERBOSE']
  end
  t.warning = false
end

YARD::Rake::YardocTask.new
