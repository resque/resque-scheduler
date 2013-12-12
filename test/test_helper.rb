
# Pretty much copied this file from the resque test_helper since we want
# to do all the same stuff

dir = File.dirname(File.expand_path(__FILE__))

require 'rubygems'
require 'test/unit'
require 'mocha/setup'
require 'resque'
require File.join(dir, '../lib/resque_scheduler')
$LOAD_PATH.unshift File.dirname(File.expand_path(__FILE__)) + '/../lib'

unless ENV['RESQUE_SCHEDULER_DISABLE_TEST_REDIS_SERVER']
  # Start our own Redis when the tests start. RedisInstance will take care of
  # starting and stopping.
  require File.expand_path('../support/redis_instance', __FILE__)
  RedisInstance.run!
end

at_exit do
  next if $!

  if defined?(MiniTest)
    exit_code = MiniTest::Unit.new.run(ARGV)
  else
    exit_code = Test::Unit::AutoRunner.run
  end

  pid = `ps -e -o pid,command | grep [r]edis-test`.split(" ")[0]
  puts "Killing test redis server..."
  Process.kill("KILL", pid.to_i)
  exit exit_code
end

`rm -f #{dir}/dump.rdb`
puts "Starting redis for testing at localhost:9736..."
`redis-server #{dir}/redis-test.conf`
Resque.redis = 'localhost:9736'

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
  klass.class_eval(&block)
end

class SomeJob
  def self.perform(repo_id, path)
  end
end

class SomeIvarJob < SomeJob
  @queue = :ivar
end
