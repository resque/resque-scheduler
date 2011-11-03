require 'bundler'

Bundler::GemHelper.install_tasks

$LOAD_PATH.unshift 'lib'

task :default => :test

# Tests
desc "Run tests"
task :test do
  Dir['test/*_test.rb'].each do |f|
    require File.expand_path(f)
  end
end

# Documentation Tasks
begin
  require 'rdoc/task'

  Rake::RDocTask.new do |rd|
    rd.main = "README.markdown"
    rd.rdoc_files.include("README.markdown", "lib/**/*.rb")
    rd.rdoc_dir = 'doc'
  end
rescue LoadError
end

