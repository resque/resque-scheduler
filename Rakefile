require 'bundler'
require 'rdoc/task'
Bundler::GemHelper.install_tasks

$LOAD_PATH.unshift 'lib'

task :default => :test

desc "Run tests"
task :test do
  Dir['test/*_test.rb'].each do |f|
    require File.expand_path(f)
  end
end

Rake::RDocTask.new do |rd|
  rd.main = "README.markdown"
  rd.rdoc_files.include("README.markdown", "lib/**/*.rb")
  rd.rdoc_dir = 'doc'
end

