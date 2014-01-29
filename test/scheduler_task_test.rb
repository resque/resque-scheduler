require_relative 'test_helper'

context "Resque::Scheduler" do
  setup do
    Resque::Scheduler.dynamic = false
    Resque.redis.flushall
    Resque::Scheduler.mute = true
    Resque::Scheduler.clear_schedule!
    Resque::Scheduler.send(:class_variable_set, :@@scheduled_jobs, {})
    Resque::Scheduler.send(:instance_variable_set, :@shutdown, false)
  end

  test "shutdown raises Interrupt when sleeping" do
    Thread.current.expects(:raise).with(Interrupt)
    Resque::Scheduler.send(:instance_variable_set, :@th, Thread.current)
    Resque::Scheduler.send(:instance_variable_set, :@sleeping, true)
    Resque::Scheduler.shutdown
  end

  test "sending TERM to scheduler breaks out of poll_sleep" do
    Resque::Scheduler.expects(:release_master_lock!)
    fork do
      sleep(0.5)
      system("kill -TERM #{Process.ppid}")
      exit!
    end

    assert_raises SystemExit do
      Resque::Scheduler.run
    end

    Resque::Scheduler.unstub(:release_master_lock!)
    Resque::Scheduler.release_master_lock!
  end
end
