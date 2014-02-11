# vim:fileencoding=utf-8
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'

task default: [:rubocop, :test]

Rubocop::RakeTask.new

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = ENV['PATTERN'] || 'test/*_test.rb'
  t.verbose = !!ENV['VERBOSE']
  t.options = "--seed #{ENV['SEED']}" if ENV['SEED']
end
