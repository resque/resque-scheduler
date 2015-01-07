# vim:fileencoding=utf-8
require_relative 'test_helper'

describe 'Resque::Scheduler' do
  before do
    Resque::Scheduler.configure do |c|
      c.dynamic = false
      c.poll_sleep_amount = 0.1
    end
    Resque.redis.flushall
    Resque::Scheduler.quiet = true
    Resque::Scheduler.clear_schedule!

    # When run with --seed  3432, the bottom test fails without the next line:
    # Minitest::Assertion: [SystemExit] exception expected, not
    # Class : <ArgumentError>
    # Message : <"\"0\" is not in range 1..31">
    # No problem when run in isolation
    Resque.schedule = {} # Schedule leaks out from other tests without this.

    Resque::Scheduler.send(:instance_variable_set, :@scheduled_jobs, {})
    Resque::Scheduler.send(:instance_variable_set, :@shutdown, false)
  end

  it 'shutdown raises Interrupt when sleeping' do
    Thread.current.expects(:raise).with(Interrupt)
    Resque::Scheduler.send(:instance_variable_set, :@th, Thread.current)
    Resque::Scheduler.send(:instance_variable_set, :@sleeping, true)
    Resque::Scheduler.shutdown
  end

  it 'sending TERM to scheduler breaks out of poll_sleep' do
    Resque::Scheduler.expects(:release_master_lock)

    @pid = Process.pid
    Thread.new do
      sleep(0.05)
      Process.kill(:TERM, @pid)
    end

    assert_raises SystemExit do
      Resque::Scheduler.run
    end

    Resque::Scheduler.unstub(:release_master_lock)
    Resque::Scheduler.release_master_lock
  end
end
