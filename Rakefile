# vim:fileencoding=utf-8
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'
require 'yard'

task default: [:testing]

RuboCop::RakeTask.new

Rake::TestTask.new(:testing) do |t|
  t.libs << 'test'
  t.pattern = ENV['PATTERN'] || 'test/*_test.rb'
  t.warning = false
  t.options = ''.tap do |o|
    o << "--seed #{ENV['SEED']} " if ENV['SEED']
    o << '--verbose ' if ENV['VERBOSE']
  end
end

YARD::Rake::YardocTask.new
