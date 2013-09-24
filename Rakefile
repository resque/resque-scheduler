require 'bundler/gem_tasks'

$LOAD_PATH.unshift 'lib'

task :default => :test

desc 'Run tests'
task :test do
  if RUBY_VERSION =~ /^1\.8/
    unless ENV['SEED']
      srand
      ENV['SEED'] = (srand % 0xFFFF).to_s
    end

    $stdout.puts "Running with SEED=#{ENV['SEED']}"
    srand Integer(ENV['SEED'])
  elsif ENV['SEED']
    ARGV += %W(--seed #{ENV['SEED']})
  end
  Dir['test/*_test.rb'].each do |f|
    require File.expand_path(f)
  end
end

desc 'Run rubocop'
task :rubocop do
  unless RUBY_VERSION < '1.9'
    sh('rubocop --config .rubocop.yml --format simple') { |r, _| r || abort }
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
