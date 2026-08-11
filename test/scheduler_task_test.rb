# vim:fileencoding=utf-8
require_relative 'test_helper'

context 'Resque::Scheduler' do
  setup do
    Resque::Scheduler.configure do |c|
      c.dynamic = false
      c.poll_sleep_amount = 0.1
    end
    Resque.data_store.redis.flushall
    Resque::Scheduler.quiet = true
    Resque::Scheduler.clear_schedule!
    Resque::Scheduler.send(:instance_variable_set, :@scheduled_jobs, {})
    Resque::Scheduler.send(:instance_variable_set, :@shutdown, false)
  end

  test 'shutdown raises Interrupt when sleeping' do
    Thread.current.expects(:raise).with(Interrupt)
    Resque::Scheduler.send(:instance_variable_set, :@th, Thread.current)
    Resque::Scheduler.send(:instance_variable_set, :@sleeping, true)
    Resque::Scheduler.shutdown
  end

  test 'sending TERM to scheduler breaks out of poll_sleep' do
    Resque::Scheduler.expects(:release_master_lock)

    pid = Process.pid
    Thread.new do
      sleep(0.05)
      Process.kill(:TERM, pid)
    end

    assert_raises SystemExit do
      Resque::Scheduler.run
    end

    Resque::Scheduler.unstub(:release_master_lock)
    Resque::Scheduler.release_master_lock
  end

  test 'can start successfully' do
    Resque::Scheduler.poll_sleep_amount = nil

    pid = Process.pid
    Thread.new do
      sleep(0.15)
      Process.kill(:TERM, pid)
    end

    assert_raises SystemExit do
      Resque::Scheduler.run
    end
  end

  test 'sending TERM to scheduler breaks out when poll_sleep_amount = 0' do
    Resque::Scheduler.poll_sleep_amount = 0
    Resque::Scheduler.expects(:release_master_lock)

    pid = Process.pid
    Thread.new do
      sleep(0.05)
      Process.kill(:TERM, pid)
    end

    assert_raises SystemExit do
      Resque::Scheduler.run
    end

    Resque::Scheduler.unstub(:release_master_lock)
    Resque::Scheduler.release_master_lock
  end

  context 'master changes' do
    setup do
      Resque::Scheduler.configure do |c|
        c.dynamic = false
        c.poll_sleep_amount = 0.1
      end
      Resque.data_store.redis.flushall
      Resque::Scheduler.quiet = true
      Resque::Scheduler.clear_schedule!
      Resque::Scheduler.send(:instance_variable_set, :@scheduled_jobs, {})
      Resque::Scheduler.send(:instance_variable_set, :@shutdown, false)

      Resque.schedule = {
        'some_ivar_job' => {
          'every' => '1h', 'class' => 'SomeIvarJob', 'args' => '/tmp'
        }
      }
    end

    # Runs the scheduler for exactly `passes` trips around the run loop by
    # raising out of the sleep at the end of the last one.  Stubbing the sleep
    # also keeps signals - which other tests leave queued - out of the way.
    def run_scheduler(passes)
      Resque::Scheduler.stubs(:poll_sleep)
                       .returns(*Array.new(passes - 1))
                       .then.raises(SystemExit)

      assert_raises SystemExit do
        Resque::Scheduler.run
      end
    end

    test 'loads the schedule on the first pass' do
      Resque::Scheduler.stubs(:master?).returns(true)

      run_scheduler(1)

      assert Resque::Scheduler.scheduled_jobs.key?('some_ivar_job')
    end

    test 'does not reload a static schedule when the master changes' do
      # master, then child, then master again
      Resque::Scheduler.stubs(:master?).returns(true, false, true)
      Resque::Scheduler.expects(:reload_schedule!).once

      run_scheduler(3)
    end

    test 'reloads a dynamic schedule when the master changes' do
      Resque::Scheduler.dynamic = true
      Resque::Scheduler.stubs(:master?).returns(true, false, true)
      Resque::Scheduler.expects(:reload_schedule!).times(3)

      run_scheduler(3)
    end
  end

  context 'logs scheduler' do
    setup do
      Resque::Scheduler.poll_sleep_amount = nil
      nullify_logger
      Resque::Scheduler.logformat = 'text'
      $stdout = StringIO.new
    end

    teardown do
      Resque::Scheduler.unstub(:master?)
      $stdout = STDOUT
    end

    test 'logs scheduler master' do
      Resque::Scheduler.expects(:master?).returns(true)

      pid = Process.pid
      Thread.new do
        sleep(0.1)
        Process.kill(:TERM, pid)
      end

      assert_raises SystemExit do
        Resque::Scheduler.run
      end

      assert $stdout.string =~ /: Master scheduler/
    end

    test 'logs scheduler child' do
      Resque::Scheduler.expects(:master?).returns(false)

      pid = Process.pid
      Thread.new do
        sleep(0.1)
        Process.kill(:TERM, pid)
      end

      assert_raises SystemExit do
        Resque::Scheduler.run
      end

      assert $stdout.string =~ /: Child scheduler/
    end
  end
end
