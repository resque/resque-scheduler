# vim:fileencoding=utf-8
require 'simplecov'

require 'resque'
# This bit needs to be above the minitest require, because otherwise, the
# at_exit calls are in the wrong order and Redis shuts down before the tests
# run.
unless ENV['RESQUE_SCHEDULER_DISABLE_TEST_REDIS_SERVER']
  # Start our own Redis when the tests start. RedisInstance will take care of
  # starting and stopping.
  require File.expand_path('../support/redis_instance', __FILE__)
  RedisInstance.run!
end

require 'minitest/autorun'
require 'mocha/setup'
require 'rack/test'

$LOAD_PATH.unshift File.dirname(File.expand_path(__FILE__)) + '/../lib'
require 'resque-scheduler'
# require 'resque/scheduler/server'

# minitest/autorun does this now.
# at_exit { exit MiniTest::Unit.new.run(ARGV) || 0 }


unless defined?(Rails)
  module Rails
    class << self
      attr_accessor :env
    end
  end
end

class FakeCustomJobClass
  def self.scheduled(_queue, _klass, *_args); end
end

class FakeCustomJobClassEnqueueAt
  @queue = :test
  def self.scheduled(_queue, _klass, *_args); end
end

class SomeJob
  def self.perform(_repo_id, _path)
  end
end

class SomeIvarJob < SomeJob
  @queue = :ivar
end

class SomeFancyJob < SomeJob
  def self.queue
    :fancy
  end
end

class SomeSharedEnvJob < SomeJob
  def self.queue
    :shared_job
  end
end

class SomeQuickJob < SomeJob
  @queue = :quick
end

class SomeRealClass
  def self.queue
    :some_real_queue
  end
end

class JobWithParams
  def self.perform(*args)
    @args = args
  end
end

JobWithoutParams = Class.new(JobWithParams)

%w(
  APP_NAME
  DYNAMIC_SCHEDULE
  LOGFILE
  LOGFORMAT
  QUIET
  RAILS_ENV
  RESQUE_SCHEDULER_INTERVAL
  VERBOSE
).each do |envvar|
  ENV[envvar] = nil
end

def nullify_logger
  Resque::Scheduler.configure do |c|
    c.quiet = nil
    c.verbose = nil
    c.logfile = nil
    c.send(:logger=, nil)
  end

  ENV['LOGFILE'] = nil
end

def restore_devnull_logfile
  nullify_logger
  ENV['LOGFILE'] = '/dev/null'
end

restore_devnull_logfile
