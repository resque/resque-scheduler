# vim:fileencoding=utf-8
require_relative 'test_helper'

context 'Env' do
  def new_env(options = {})
    Resque::Scheduler::Env.new(options)
  end

  test 'daemonizes when background is true' do
    Process.expects(:daemon)
    env = new_env(background: true)
    env.setup
  end

  test 'reconnects redis when background is true' do
    Process.stubs(:daemon)
    mock_redis_client = mock('redis_client')
    mock_redis = mock('redis')
    mock_redis.expects(:client).returns(mock_redis_client)
    mock_redis_client.expects(:reconnect)
    Resque.expects(:redis).returns(mock_redis)
    env = new_env(background: true)
    env.setup
  end

  test 'aborts when background is given and Process does not support daemon' do
    Process.stubs(:daemon)
    Process.expects(:respond_to?).with('daemon').returns(false)
    env = new_env(background: true)
    env.expects(:abort)
    env.setup
  end

  [true, false].each do |manual_cleanup|
    desc = manual_cleanup ? 'manually' : 'automatically'
    test "writes pid to pidfile when given and cleans up #{desc}" do
      require 'weakref'

      options = { pidfile: 'derp.pid' }
      pidfile_path = File.expand_path(options[:pidfile])

      mock_pidfile = mock('pidfile')
      mock_pidfile.expects(:puts).with(Process.pid)
      File.expects(:open).with(pidfile_path, 'w').yields(mock_pidfile)

      env = new_env(options)
      env_weakref = WeakRef.new(env)
      env.setup

      # When the pidfile gets cleaned up, we should get a delete
      File.expects(:exist?).with(pidfile_path).returns(true).once
      File.expects(:delete).with(pidfile_path).returns(true).once

      env.cleanup if manual_cleanup

      # we want env to go out of scope so we can GC it
      # and validate that the pidfile got cleaned up
      # rubocop:disable Lint/UselessAssignment
      env = nil
      # rubocop:enable Lint/UselessAssignment

      # Force GC to kickoff the finalizer
      gc_was_disabled = GC.enable
      10.times do
        GC.start
        break unless env_weakref.weakref_alive?
        sleep 0.1
      end
      GC.disable if gc_was_disabled
    end
  end

  test 'keep set config if no option given' do
    Resque::Scheduler.configure { |c| c.dynamic = true }
    env = new_env
    env.setup
    assert_equal(true, Resque::Scheduler.dynamic)
  end

  test 'override config if option given' do
    Resque::Scheduler.configure { |c| c.dynamic = true }
    env = new_env(dynamic: false)
    env.setup
    assert_equal(false, Resque::Scheduler.dynamic)
  end
end
