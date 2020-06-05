# -*- encoding: utf-8 -*-
$:.unshift File.expand_path("../lib", __FILE__)
require "resque_scheduler/version"

Gem::Specification.new do |s|
  s.name        = "resque-scheduler"
  s.version     = ResqueScheduler::VERSION
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

  s.add_runtime_dependency 'redis', '~> 3.0.0'
  s.add_runtime_dependency 'resque', '>= 1.22'
  s.add_runtime_dependency 'rufus-scheduler', '~> 2.0'
end
