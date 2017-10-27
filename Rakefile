# vim:fileencoding=utf-8
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'
require 'yard'

task default: [:rubocop, :test] unless RUBY_PLATFORM =~ /java/
task default: [:test] if RUBY_PLATFORM =~ /java/

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

task :test do
  puts
  puts
  puts "Running tests without migrator patch"

  ENV['TEST_WITH_MIGRATOR'] = nil
  Rake::Task[:testing].invoke

  puts
  puts
  puts "Running tests with migrator patch"

  ENV['TEST_WITH_MIGRATOR'] = "1"
  Rake::Task[:testing].reenable
  Rake::Task[:testing].invoke
end

YARD::Rake::YardocTask.new
