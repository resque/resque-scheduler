require File.dirname(__FILE__) + '/test_helper'

context "Resque::Scheduler" do
  setup do
    nullify_logger
    Resque::Scheduler.dynamic = false
    Resque.redis.flushall
    Resque::Scheduler.clear_schedule!
  end

  teardown { restore_devnull_logfile }

  test 'set custom logger' do
    custom_logger = Logger.new('/dev/null')
    Resque::Scheduler.logger = custom_logger
    assert_equal(custom_logger, Resque::Scheduler.logger)
  end

  test 'configure block' do
    Resque::Scheduler.mute = false
    Resque::Scheduler.configure do |c|
      c.mute = true
    end
    assert_equal(Resque::Scheduler.mute, true)
  end

  context 'logger default settings' do
    setup { nullify_logger }
    teardown { restore_devnull_logfile }

    test 'uses STDOUT' do
      assert_equal(
        Resque::Scheduler.logger.instance_variable_get(:@logdev).dev, $stdout
      )
    end

    test 'not verbose' do
      assert Resque::Scheduler.logger.level > Logger::DEBUG
    end

    test 'not muted' do
      assert Resque::Scheduler.logger.level < Logger::FATAL
    end
  end

  context 'logger custom settings' do
    setup { nullify_logger }
    teardown { restore_devnull_logfile }

    test 'uses logfile' do
      Resque::Scheduler.logfile = '/dev/null'
      assert_equal(
        Resque::Scheduler.logger.instance_variable_get(:@logdev).filename,
        '/dev/null'
      )
    end

    test 'set verbosity' do
      Resque::Scheduler.verbose = true
      assert Resque::Scheduler.logger.level == Logger::DEBUG
    end

    test 'mute logger' do
      Resque::Scheduler.mute = true
      assert Resque::Scheduler.logger.level == Logger::FATAL
    end
  end
end
