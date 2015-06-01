# vim:fileencoding=utf-8

require_relative 'test_helper'
class JamesJob < ActiveJob::Base
  def perform(*args);end
end

context 'scheduling jobs with arguments' do
  setup do
    Resque::Scheduler.clear_schedule!
    Resque::Scheduler.configure do |c|
      c.dynamic = false
      c.quiet = true
      c.poll_sleep_amount = nil
    end
  end

  context 'breaking change : big boom' do
    # mfo, respect method signature and runtime definition
    test 'enqueue_from_config raises a Resque::NoClassError for undefined job' do
      assert_raises Resque::NoClassError do
        Resque::Scheduler.enqueue_from_config(
          'cron' => '* * * * *',
          'class' => 'UndefinedJob',
          'args' => '/tmp',
          'queue' => 'joes_queue'
        )
      end
    end

    # do not enqueue an undefined job
    test 'enqueue_from_config raises an ArgumentError if' \
      'job signature is not respected [void argv]' do
      config = YAML.load(%Q(
        class: SomeIvarJob
      ))

      assert_raise ArgumentError do
        Resque::Scheduler.enqueue_from_config(config)
      end
    end

    test 'enqueue_from_config raises an ArgumentError if' \
      'job signature is not respected [incomplete argv]' do
      crappy_config = YAML.load(%Q(
        class: SomeIvarJob
        args:
      ))
      assert_raise ArgumentError do
        Resque::Scheduler.enqueue_from_config(crappy_config)
      end
    end
  end



  test 'enqueue_from_config with_every_syntax' do
    mock = Minitest::Mock.new().expect(:perform_later, true, ['/tmp'])
    ActiveJob::ConfiguredJob.stubs(:new).with(JamesJob, queue: 'james_queue').returns(mock)
    Resque::Scheduler.enqueue_from_config(
      'every' => '1m',
      'class' => 'JamesJob',
      'args' => '/tmp',
      'queue' => 'james_queue'
    )
    mock.verify
  end

  test 'enqueue_from_config puts jobs in the resque queue' do
    mock = Minitest::Mock.new().expect(:perform_later, true, ['/tmp'])
    ActiveJob::ConfiguredJob.stubs(:new).with(SomeIvarJob, queue: 'ivar').returns(mock)

    Resque::Scheduler.enqueue_from_config(
      'cron' => '* * * * *',
      'class' => 'SomeIvarJob',
      'args' => '/tmp'
    )
    mock.verify
  end

  test 'enqueue_from_config with custom_class_job in resque' do
    FakeCustomJobClass.stubs(:scheduled).once.returns(true)
      .with('ivar', 'SomeIvarJob', '/tmp')
    Resque::Scheduler.enqueue_from_config(
      'cron' => '* * * * *',
      'class' => 'SomeIvarJob',
      'custom_job_class' => 'FakeCustomJobClass',
      'args' => '/tmp'
    )
  end

  test 'enqueue_from_config puts stuff in resque when env matches' do
    Resque::Scheduler.env = 'production'
    assert_equal(0, Resque::Scheduler.rufus_scheduler.jobs.size)

    Resque.schedule = {
      'some_ivar_job' => {
        'cron' => '* * * * *',
        'class' => 'SomeIvarJob',
        'args' => '/tmp',
        'rails_env' => 'production'
      }
    }

    Resque::Scheduler.load_schedule!
    assert_equal(1, Resque::Scheduler.rufus_scheduler.jobs.size)

    Resque.schedule = {
      'some_ivar_job' => {
        'cron' => '* * * * *',
        'class' => 'SomeIvarJob',
        'args' => '/tmp',
        'env' => 'staging, production'
      }
    }

    Resque::Scheduler.load_schedule!
    assert_equal(2, Resque::Scheduler.rufus_scheduler.jobs.size)
  end

  test 'enqueue_from_config does not enqueue when env does not match' do
    Resque::Scheduler.env = nil
    assert_equal(0, Resque::Scheduler.rufus_scheduler.jobs.size)
    Resque.schedule = {
      'some_ivar_job' => {
        'cron' => '* * * * *',
        'class' => 'SomeIvarJob',
        'args' => '/tmp',
        'rails_env' => 'staging'
      }
    }

    Resque::Scheduler.load_schedule!
    assert_equal(0, Resque::Scheduler.rufus_scheduler.jobs.size)

    Resque::Scheduler.env = 'production'
    Resque.schedule = {
      'some_ivar_job' => {
        'cron' => '* * * * *',
        'class' => 'SomeIvarJob',
        'args' => '/tmp',
        'env' => 'staging'
      }
    }
    Resque::Scheduler.load_schedule!
    assert_equal(0, Resque::Scheduler.rufus_scheduler.jobs.size)
  end

  test 'enqueue_from_config when env env arg is not set' do
    Resque::Scheduler.env = 'production'
    assert_equal(0, Resque::Scheduler.rufus_scheduler.jobs.size)

    Resque.schedule = {
      'some_ivar_job' => {
        'cron' => '* * * * *',
        'class' => 'SomeIvarJob',
        'args' => '/tmp'
      }
    }
    Resque::Scheduler.load_schedule!
    assert_equal(1, Resque::Scheduler.rufus_scheduler.jobs.size)
  end


  test 'calls the worker with a string when the config lists a string' do
    config = YAML.load(%Q(
      class: SomeJobString
      args: string
    ))
    mock = Minitest::Mock.new().expect(:perform_later, true, ['string'])
    ActiveJob::ConfiguredJob.stubs(:new).with(SomeJobString, queue: 'ivar').returns(mock)

    Resque::Scheduler.enqueue_from_config(config)
    mock.verify
  end

  test 'calls the worker with a Fixnum when the config lists an integer' do
    config = YAML.load(%Q(
      class: SomeJobFixnum
      args: 1
    ))
    mock = Minitest::Mock.new().expect(:perform_later, true, [1])
    ActiveJob::ConfiguredJob.stubs(:new).with(SomeJobFixnum, queue: 'ivar').returns(mock)

    Resque::Scheduler.enqueue_from_config(config)
    mock.verify
  end

  test 'calls the worker with multiple arguments when the config ' \
       'lists an array' do
    config = YAML.load(%Q(
      class: SomeIvarJob
      args:
        - 1
        - 2
    ))
    mock = Minitest::Mock.new().expect(:perform_later, true, [1, 2])
    ActiveJob::ConfiguredJob.stubs(:new).with(SomeIvarJob, queue: 'ivar').returns(mock)
    Resque::Scheduler.enqueue_from_config(config)
    mock.verify
  end

  test 'calls the worker with an array when the config lists ' \
       'a nested array' do
    config = YAML.load(%Q(
      class: SomeJobArray
      args:
        - - 1
          - 2
    ))
    mock = Minitest::Mock.new().expect(:perform_later, true, [[1, 2]])
    ActiveJob::ConfiguredJob.stubs(:new).with(SomeJobArray, queue: 'ivar').returns(mock)
    Resque::Scheduler.enqueue_from_config(config)
    mock.verify
  end

  test 'calls the worker with a hash when the config lists a hash' do
    config = YAML.load(%Q(
      class: SomeJobHash
      args:
        key: value
    ))
    mock = Minitest::Mock.new().expect(:perform_later, true, [{'key' => 'value'}])
    ActiveJob::ConfiguredJob.stubs(:new).with(SomeJobHash, queue: 'ivar').returns(mock)

    Resque::Scheduler.enqueue_from_config(config)
    mock.verify
  end

  test 'calls the worker with a nested hash when the config lists ' \
       'a nested hash' do
    config = YAML.load(%Q(
      class: SomeJobHash
      args:
        first_key:
          second_key: value
    ))
    mock = Minitest::Mock.new().expect(:perform_later, true, ['first_key' => { 'second_key' => 'value' }])
    ActiveJob::ConfiguredJob.stubs(:new).with(SomeJobHash, queue: 'ivar').returns(mock)

    Resque::Scheduler.enqueue_from_config(config)
    mock.verify
  end

  test 'poll_sleep_amount defaults to 5' do
    assert_equal 5, Resque::Scheduler.poll_sleep_amount
  end

  test 'poll_sleep_amount is settable' do
    Resque::Scheduler.poll_sleep_amount = 1
    assert_equal 1, Resque::Scheduler.poll_sleep_amount
  end
end
