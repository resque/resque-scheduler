# vim:fileencoding=utf-8
require_relative 'resque/scheduler'
require 'resque/scheduler/engine'

Resque.extend Resque::Scheduler::Extension
