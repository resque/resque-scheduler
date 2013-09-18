require 'bundler/gem_tasks'

$LOAD_PATH.unshift 'lib'

task :default => :test

# Tests
desc "Run tests"
task :test do
  if RUBY_VERSION =~ /^1\.8/
    unless ENV['SEED']
      srand
      ENV['SEED'] = (srand % 0xFFFF).to_s
    end

    $stdout.puts "Running with SEED=#{ENV['SEED']}"
    srand Integer(ENV['SEED'])
  end
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

