load File.expand_path('tasks/resque_scheduler.rake')

$LOAD_PATH.unshift 'lib'

task :default => :test

desc "Run tests"
task :test do
  Dir['test/*_test.rb'].each do |f|
    require File.expand_path(f)
  end
end


desc "Build a gem"
task :gem => [ :test, :gemspec, :build ]

begin
  begin
    require 'jeweler'
  rescue LoadError
    puts "Jeweler not available. Install it with: "
    puts "gem install jeweler"
  end

  require 'resque_scheduler/version'

  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "brianjlandau-resque-scheduler"
    gemspec.summary = "Light weight job scheduling on top of Resque"
    gemspec.description = %{Light weight job scheduling on top of Resque.
  Adds methods enqueue_at/enqueue_in to schedule jobs in the future.
  Also supports queueing jobs on a fixed, cron-like schedule.}
    gemspec.email = "brianjlandau@gmail.com"
    gemspec.homepage = "http://github.com/brianjlandau/resque-scheduler"
    gemspec.authors = ["Ben VandenBos", "Brian Landau"]
    gemspec.version = ResqueScheduler::Version

    gemspec.add_dependency "redis", ">= 2.0.1"
    gemspec.add_dependency "resque", ">= 1.8.0"
    gemspec.add_dependency "rufus-scheduler"
    gemspec.add_development_dependency "jeweler"
    gemspec.add_development_dependency "mocha"
    gemspec.add_development_dependency "rack-test"
  end
  
  Jeweler::GemcutterTasks.new
end
