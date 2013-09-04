
# Pretty much copied this file from the resque test_helper since we want
# to do all the same stuff

dir = File.dirname(File.expand_path(__FILE__))

require 'rubygems'
require 'test/unit'
require 'mocha/setup'
require 'resque'
$LOAD_PATH.unshift File.dirname(File.expand_path(__FILE__)) + '/../lib'
require 'resque_scheduler'
require 'resque_scheduler/server'

#
# make sure we can run redis
#

if !system("which redis-server")
  puts '', "** can't find `redis-server` in your path"
  puts "** try running `sudo rake install`"
  abort ''
end


# Start our own Redis when the tests start. RedisInstance will take care of
# starting and stopping.
require File.dirname(__FILE__) + '/support/redis_instance'
RedisInstance.run!

at_exit do
  next if $!

  if defined?(MiniTest)
    exit_code = MiniTest::Unit.new.run(ARGV)
  else
    exit_code = Test::Unit::AutoRunner.run
  end

  exit exit_code
end

##
# test/spec/mini 3
# http://gist.github.com/25455
# chris@ozmm.org
#
def context(*args, &block)
  return super unless (name = args.first) && block
  require 'test/unit'
  klass = Class.new(defined?(ActiveSupport::TestCase) ? ActiveSupport::TestCase : Test::Unit::TestCase) do
    def self.test(name, &block)
      define_method("test_#{name.gsub(/\W/,'_')}", &block) if block
    end
    def self.xtest(*args) end
    def self.setup(&block) define_method(:setup, &block) end
    def self.teardown(&block) define_method(:teardown, &block) end
  end
  (class << klass; self end).send(:define_method, :name) { name.gsub(/\W/,'_') }
  klass.class_eval &block
end

class FakeCustomJobClass
  def self.scheduled(queue, klass, *args); end
end

class FakeCustomJobClassEnqueueAt
  @queue = :test
  def self.scheduled(queue, klass, *args); end
end

class SomeJob
  def self.perform(repo_id, path)
  end
end

class SomeIvarJob < SomeJob
  @queue = :ivar
end

class SomeRealClass
  def self.queue
    :some_real_queue
  end
end
