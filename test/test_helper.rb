# vim:fileencoding=utf-8
require 'simplecov'
require 'minitest/autorun'
require 'minitest/unit'
require 'test/unit'
require 'minitest'
require 'mocha/setup'
require 'rack/test'
require 'resque'
require 'active_job'
$LOAD_PATH.unshift File.dirname(File.expand_path(__FILE__)) + '/../lib'
require 'resque-scheduler'
require 'resque/scheduler/server'
ActiveJob::Base.queue_adapter = :resque
##
# test/spec/mini 3
# original work: http://gist.github.com/25455
# forked and modified: https://gist.github.com/meatballhat/8906709
#
def context(*args, &block)
  return super unless (name = args.first) && block
  require 'test/unit'
  klass = Class.new(Test::Unit::TestCase) do
    def self.test(name, &block)
      define_method("test_#{name.gsub(/\W/, '_')}", &block) if block
    end

    def self.xtest(*_args)
    end

    def self.setup(&block)
      define_method(:setup, &block)
    end

    def self.teardown(&block)
      define_method(:teardown, &block)
    end
  end
  (class << klass; self end).send(:define_method, :name) do
    name.gsub(/\W/, '_')
  end
  klass.class_eval(&block)
end

unless defined?(Rails)
  module Rails
    class << self
      attr_accessor :env
    end
  end
end

class FakeCustomJobClass < ActiveJob::Base
  def self.scheduled(_queue, _klass, *_args)
  end
end

class FakeCustomJobClassEnqueueAt < ActiveJob::Base
  queue_as :test
  def self.scheduled(_queue, _klass, *_args)
  end
end

class DummyJob < ActiveJob::Base
  queue_as :ivar
  def perform
  end
end

class SomeJob < ActiveJob::Base
  def perform(_repo_id, _path)
  end
end

class SomeJobArray < ActiveJob::Base
  queue_as :ivar
  def perform(_arr)
  end
end

class SomeJobString < ActiveJob::Base
  queue_as :ivar
  def perform(_str)
  end
end

class SomeJobHash < ActiveJob::Base
  queue_as :ivar
  def perform(_hash)
  end
end

class SomeJobFixnum < ActiveJob::Base
  queue_as :ivar
  def perform(_fixnum)
  end
end

class ExceptionHandlerClass
  def self.on_enqueue_failure(_, _)
  end
end

class SomeIvarJob < SomeJob
  queue_as :ivar
end

class SomeFancyJob < SomeJob
  queue_as :fancy
end

class SomeSharedEnvJob < SomeJob
  queue_as :shared_job
end

class SomeQuickJob < SomeJob
  queue_as :quick
end

class SomeRealClass < ActiveJob::Base
  queue_as :some_real_queue
  def perform(_argv)
  end
end

class JobWithParams < ActiveJob::Base
  def perform(*args)
  end
end

class SomeJobWithResqueHooks < SomeRealClass
  def before_enqueue_example
  end

  def after_enqueue_example
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
    c.logger = nil
  end

  ENV['LOGFILE'] = nil
end

def devnull_logfile
  @devnull_logfile ||= (
    RUBY_PLATFORM =~ /mingw|windows/i ? 'nul' : '/dev/null'
  )
end

def restore_devnull_logfile
  nullify_logger
  ENV['LOGFILE'] = devnull_logfile
end

def with_failure_handler(handler)
  original_handler = Resque::Scheduler.failure_handler
  Resque::Scheduler.failure_handler = handler
  yield
ensure
  Resque::Scheduler.failure_handler = original_handler
end

restore_devnull_logfile
