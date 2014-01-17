require 'bundler/gem_tasks'
require 'rake/testtask'

task default: [:rubocop, :test]

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = ENV['PATTERN'] || 'test/*_test.rb'
  t.verbose = !!ENV['VERBOSE']
  t.options = "--seed #{ENV['SEED']}" if ENV['SEED']
end

desc 'Run rubocop'
task :rubocop do
  unless RUBY_VERSION < '1.9'
    sh('rubocop --format simple') { |ok, _| ok || abort }
  end
end

begin
  require 'rdoc/task'

  Rake::RDocTask.new do |rd|
    rd.main = 'README.md'
    rd.rdoc_files.include('README.md', 'lib/**/*.rb')
    rd.rdoc_dir = 'doc'
  end
rescue LoadError
end
