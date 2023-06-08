require 'simplecov'

require 'test/unit'
require 'minitest'
require 'mocha/test_unit'
require 'rack/test'
require 'resque'
require 'timecop'

$LOAD_PATH.unshift File.dirname(File.expand_path(__FILE__)) + '/../lib'
require 'resque-scheduler'
require 'resque/scheduler/server'

# Raise on Redis deprecations if we're using a modern enough version of the Resque gem
if Redis.respond_to?(:'raise_deprecations=')
  Redis.raise_deprecations = Gem.loaded_specs['resque'].version >= Gem::Version.create('2.4') &&
    Gem.loaded_specs['redis'].version >= Gem::Version.create('5.0')
end

if RUBY_VERSION >= '2.7.0'
  Mocha.configure do |c|
    c.strict_keyword_argument_matching = true
  end
end

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

class ExceptionHandlerClass
  def self.on_enqueue_failure(_, _); end
end

class FakeCustomJobClass
  def self.scheduled(_, _, *_); end
end

class FakeCustomJobClassEnqueueAt
  @queue = :test
  def self.scheduled(_, _, *_); end
end

class SomeJob
  def self.perform(_, _)
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

class SomeJobWithResqueHooks < SomeRealClass
  def before_enqueue_example; end

  def after_enqueue_example; end
end

class JobWithParams
  def self.perform(*args)
    @args = args
  end
end

JobWithoutParams = Class.new(JobWithParams)

class FakePHPClass < SomeJob
  @queue = :'some-other-kinda::queue-maybe'

  def self.to_s
    'Namespace\\For\\Job\\Class'
  end
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

# Copied from https://stackoverflow.com/questions/4975747/sleep-until-condition-is-true-in-ruby
def sleep_until(time, delay = 0.1)
  time.times do
    yielded = yield
    return yielded if yielded
    sleep(delay)
  end
  nil
end

restore_devnull_logfile
