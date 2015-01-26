# vim:fileencoding=utf-8
require_relative 'test_helper'

describe 'Resque::Scheduler' do
  before do
    reset_resque_scheduler
    Resque::Scheduler.configure do |c|
      c.poll_sleep_amount = 0.1
    end
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
