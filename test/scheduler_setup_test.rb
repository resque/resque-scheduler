# vim:fileencoding=utf-8
require_relative 'test_helper'

describe 'Resque::Scheduler' do
  before do
    reset_resque_scheduler

    ENV['VERBOSE'] = nil
    nullify_logger
  end

  after { restore_devnull_logfile }

  it 'set custom logger' do
    custom_logger = MonoLogger.new('/dev/null')
    Resque::Scheduler.send(:logger=, custom_logger)
    assert_equal(custom_logger, Resque::Scheduler.send(:logger))
  end

  it 'configure block' do
    Resque::Scheduler.quiet = false
    Resque::Scheduler.configure do |c|
      c.quiet = true
    end
    assert_equal(Resque::Scheduler.quiet, true)
  end

  describe 'when getting the env' do
    def wipe
      Resque::Scheduler.env = nil
      Rails.env = nil
      ENV['RAILS_ENV'] = nil
    end

    before do
      reset_resque_scheduler
      wipe
    end
    after { wipe }

    it 'uses the value if set' do
      Resque::Scheduler.env = 'foo'
      assert_equal('foo', Resque::Scheduler.env)
    end

    it 'uses Rails.env if present' do
      Rails.env = 'bar'
      assert_equal('bar', Resque::Scheduler.env)
    end

    it 'uses $RAILS_ENV if present' do
      ENV['RAILS_ENV'] = 'baz'
      assert_equal('baz', Resque::Scheduler.env)
    end
  end

  describe 'logger default settings' do
    before do
      reset_resque_scheduler
      nullify_logger
    end
    after { restore_devnull_logfile }

    it 'uses STDOUT' do
      assert_equal(
        Resque::Scheduler.send(:logger)
          .instance_variable_get(:@logdev).dev, $stdout
      )
    end

    it 'not verbose' do
      assert Resque::Scheduler.send(:logger).level > MonoLogger::DEBUG
    end

    it 'not quieted' do
      assert Resque::Scheduler.send(:logger).level < MonoLogger::FATAL
    end
  end

  describe 'logger custom settings' do
    before do
      reset_resque_scheduler
      nullify_logger
    end
    after { restore_devnull_logfile }

    it 'uses logfile' do
      Resque::Scheduler.logfile = '/dev/null'
      assert_equal(
        Resque::Scheduler.send(:logger)
          .instance_variable_get(:@logdev).filename,
        '/dev/null'
      )
    end

    it 'set verbosity' do
      Resque::Scheduler.verbose = true
      assert Resque::Scheduler.send(:logger).level == MonoLogger::DEBUG
    end

    it 'quiet logger' do
      Resque::Scheduler.quiet = true
      assert Resque::Scheduler.send(:logger).level == MonoLogger::FATAL
    end
  end

  describe 'logger with json formatter' do
    before do
      reset_resque_scheduler
      nullify_logger
      Resque::Scheduler.logformat = 'json'
      $stdout = StringIO.new
    end

    after do
      $stdout = STDOUT
    end

    it 'logs with json' do
      Resque::Scheduler.log! 'whatever'
      assert $stdout.string =~ /"msg":"whatever"/
    end
  end

  describe 'logger with text formatter' do
    before do
      reset_resque_scheduler
      nullify_logger
      Resque::Scheduler.logformat = 'text'
      $stdout = StringIO.new
    end

    after do
      $stdout = STDOUT
    end

    it 'logs with text' do
      Resque::Scheduler.log! 'another thing'
      assert $stdout.string =~ /: another thing/
    end
  end
end
