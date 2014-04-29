# vim:fileencoding=utf-8
require_relative 'resque/scheduler'
require_relative 'resque_scheduler'

Resque.extend Resque::Scheduler::Extension
