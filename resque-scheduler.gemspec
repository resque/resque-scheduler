# -*- encoding: utf-8 -*-
require File.expand_path("../lib/resque_scheduler/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "resque-scheduler"
  s.version     = ResqueScheduler::Version
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Ben VandenBos']
  s.email       = ['bvandenbos@gmail.com']
  s.homepage    = "http://github.com/bvandenbos/resque-scheduler"
  s.summary     = "Light weight job scheduling on top of Resque"
  s.description = %q{Light weight job scheduling on top of Resque.
    Adds methods enqueue_at/enqueue_in to schedule jobs in the future.
    Also supports queueing jobs on a fixed, cron-like schedule.}
  
  s.required_rubygems_version = ">= 1.3.6"
  s.add_development_dependency "bundler", ">= 1.0.0"

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
  
  s.add_runtime_dependency(%q<redis>, [">= 2.0.1"])
  s.add_runtime_dependency(%q<resque>, [">= 1.8.0"])
  s.add_runtime_dependency(%q<rufus-scheduler>, [">= 0"])
  s.add_development_dependency(%q<mocha>, [">= 0"])
  s.add_development_dependency(%q<rack-test>, [">= 0"])
  
end
