load 'tasks/resque_scheduler.rake'

$LOAD_PATH.unshift 'lib'

task :default => :test

desc "Run tests"
task :test do
  Dir['test/*_test.rb'].each do |f|
    require f
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
    gemspec.name = "resque-scheduler"
    gemspec.summary = ""
    gemspec.description = ""
    gemspec.email = "bvandenbos@gmail.com"
    gemspec.homepage = "http://github.com/bvandenbos/resque-scheduler"
    gemspec.authors = ["Ben VandenBos"]
    gemspec.version = ResqueScheduler::Version

    gemspec.add_dependency "resque", ">= 1.3.0"
    gemspec.add_dependency "rufus-scheduler"
    gemspec.add_development_dependency "jeweler"
    gemspec.add_development_dependency "mocha"
  end
end


desc "Push a new version to Gemcutter"
task :publish => [ :test, :gemspec, :build ] do
  system "git tag v#{ResqueScheduler::Version}"
  system "git push origin v#{ResqueScheduler::Version}"
  system "git push origin master"
  system "gem push pkg/resque-#{ResqueScheduler::Version}.gem"
  system "git clean -fd"
  exec "rake pages"
end
