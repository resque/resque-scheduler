# vim:fileencoding=utf-8
require_relative 'test_helper'

module HookTestHelper
  def enqueued
    Resque.redis.lrange("queue:#{SomeRealClass.queue}", 0, -1).map(&JSON.method(:parse))
  end
end

context 'scheduling jobs with hooks' do
  include HookTestHelper

  setup { Resque.data_store.redis.flushall }

  def config
    {
      'cron' => '* * * * *',
      'class' => 'SomeRealClass',
      'args' => '/tmp'
    }
  end


  test 'no scheduler hooks are called when enqueued from config' do
    SomeRealClass.expects(:before_schedule_example).never
    SomeRealClass.expects(:after_schedule_example).never
    SomeRealClass.expects(:before_delayed_enqueue_example).never
    SomeRealClass.expects(:before_recurring_example).never
    SomeRealClass.expects(:after_recurring_example).never
    Resque::Scheduler.enqueue(config)

    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['/tmp'] }], enqueued
  end

  test 'before_schedule hook that does not return false should be enqueued' do
    enqueue_time = Time.now + 60
    SomeRealClass.expects(:before_schedule_example).with('foo')
    SomeRealClass.expects(:after_schedule_example).with('foo')
    Resque.enqueue_at(enqueue_time.to_i, SomeRealClass, 'foo')
    assert_equal(1, Resque.delayed_timestamp_size(enqueue_time.to_i),
                 'job should be enqueued')
  end

  test 'before_schedule hook that returns false should not be enqueued' do
    enqueue_time = Time.now + 60
    SomeRealClass.expects(:before_schedule_example).with('foo').returns(false)
    SomeRealClass.expects(:after_schedule_example).never
    Resque.enqueue_at(enqueue_time.to_i, SomeRealClass, 'foo')
    assert_equal(0, Resque.delayed_timestamp_size(enqueue_time.to_i),
                 'job should not be enqueued')
  end

  test 'schedule hooks are not called when timestamp is in the past' do
    SomeRealClass.expects(:before_schedule_example).never
    SomeRealClass.expects(:after_schedule_example).never

    past_time = Time.now - 3600
    Resque.enqueue_at(past_time, SomeRealClass, :foo)

    assert_equal(0, Resque.count_all_scheduled_jobs,
                 'job should not be in delayed queue')
    assert_equal(1, Resque.redis.llen("queue:#{SomeRealClass.queue}"),
                 'job should be in work queue')
  end

  test 'schedule hooks are not called when timestamp equals now' do
    Timecop.freeze do
      SomeRealClass.expects(:before_schedule_example).never
      SomeRealClass.expects(:after_schedule_example).never

      Resque.enqueue_at(Time.now, SomeRealClass, :foo)

      assert_equal(0, Resque.count_all_scheduled_jobs,
                   'job should not be in delayed queue')
      assert_equal(1, Resque.redis.llen("queue:#{SomeRealClass.queue}"),
                   'job should be in work queue')
    end
  end

  test 'schedule hooks are called when timestamp is in the future' do
    future_time = Time.now + 3600
    SomeRealClass.expects(:before_schedule_example).with(:foo)
    SomeRealClass.expects(:after_schedule_example).with(:foo)

    Resque.enqueue_at(future_time, SomeRealClass, :foo)

    assert_equal(1, Resque.count_all_scheduled_jobs,
                 'job should be in delayed queue')
    assert_equal(0, Resque.redis.llen("queue:#{SomeRealClass.queue}"),
                 'job should not be in work queue')
  end

  test 'resque enqueue hooks are called when timestamp is in the past' do
    SomeJobWithResqueHooks.expects(:before_enqueue_example).with(:foo)
    SomeJobWithResqueHooks.expects(:after_enqueue_example).with(:foo)

    past_time = Time.now - 3600
    Resque.enqueue_at(past_time, SomeJobWithResqueHooks, :foo)

    assert_equal(0, Resque.count_all_scheduled_jobs,
                 'job should not be in delayed queue')
    assert_equal(1, Resque.redis.llen("queue:#{SomeJobWithResqueHooks.queue}"),
                 'job should be in work queue')
  end

  test 'resque enqueue hooks are called when timestamp equals now' do
    Timecop.freeze do
      SomeJobWithResqueHooks.expects(:before_enqueue_example).with(:foo)
      SomeJobWithResqueHooks.expects(:after_enqueue_example).with(:foo)

      Resque.enqueue_at(Time.now, SomeJobWithResqueHooks, :foo)

      assert_equal(0, Resque.count_all_scheduled_jobs,
                   'job should not be in delayed queue')
      assert_equal(1, Resque.redis.llen("queue:#{SomeJobWithResqueHooks.queue}"),
                   'job should be in work queue')
    end
  end

  test 'resque enqueue hooks are not called when timestamp is in the future' do
    SomeJobWithResqueHooks.expects(:before_enqueue_example).never
    SomeJobWithResqueHooks.expects(:after_enqueue_example).never

    future_time = Time.now + 3600
    Resque.enqueue_at(future_time, SomeJobWithResqueHooks, :foo)

    assert_equal(1, Resque.count_all_scheduled_jobs,
                 'job should be in delayed queue')
    assert_equal(0, Resque.redis.llen("queue:#{SomeJobWithResqueHooks.queue}"),
                 'job should not be in work queue')
  end

  test 'default failure hooks are called when enqueueing a job fails' do
    e = RuntimeError.new('custom error')
    Resque::Scheduler.expects(:enqueue_from_config).raises(e)

    Resque::Scheduler::FailureHandler.expects(:on_enqueue_failure).with(config, e)
    Resque::Scheduler.enqueue(config)
  end

  test 'failure hooks are called when enqueueing a job fails' do
    with_failure_handler(ExceptionHandlerClass) do
      e = RuntimeError.new('custom error')
      Resque::Scheduler.expects(:enqueue_from_config).raises(e)

      ExceptionHandlerClass.expects(:on_enqueue_failure).with(config, e)

      Resque::Scheduler.enqueue(config)
    end
  end
end

context 'delayed job hooks' do
  include HookTestHelper

  setup do
    Resque::Scheduler.quiet = true
    Resque.data_store.redis.flushall
  end

  def future_time
    @future_time ||= Time.now + 600
  end

  test 'schedule hooks are called once over the life of a delayed job' do
    SomeRealClass.expects(:before_schedule_example).with('foo').once
    SomeRealClass.expects(:after_schedule_example).with('foo').once
    SomeRealClass.expects(:before_delayed_enqueue_example).with('foo').once
    SomeRealClass.expects(:before_recurring_example).never
    SomeRealClass.expects(:after_recurring_example).never

    Resque.enqueue_at(future_time, SomeRealClass, 'foo')
    Resque::Scheduler.handle_delayed_items(future_time)

    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['foo'] }], enqueued
  end

  test 'before_schedule returning false does not drop a due delayed job' do
    Resque.enqueue_at(future_time, SomeRealClass, 'foo')
    SomeRealClass.stubs(:before_schedule_example).returns(false)

    Resque::Scheduler.handle_delayed_items(future_time)

    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['foo'] }], enqueued
  end

  test 'before_delayed_enqueue returning false does not stop a due delayed job' do
    Resque.enqueue_at(future_time, SomeRealClass, 'foo')
    SomeRealClass.stubs(:before_delayed_enqueue_example).returns(false)

    Resque::Scheduler.handle_delayed_items(future_time)

    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['foo'] }], enqueued
  end

  test 'failure hooks are called when a before_delayed_enqueue hook raises' do
    Resque.enqueue_at(future_time, SomeRealClass, 'foo')
    e = RuntimeError.new('custom error')
    SomeRealClass.expects(:before_delayed_enqueue_example).raises(e)
    Resque::Scheduler::FailureHandler.expects(:on_enqueue_failure)
                                     .with(has_entry('class', 'SomeRealClass'), e)

    Resque::Scheduler.handle_delayed_items(future_time)
  end

  def expect_only_delayed_enqueue_hooks
    SomeRealClass.expects(:before_delayed_enqueue_example).with('foo').once
    SomeRealClass.expects(:before_schedule_example).never
    SomeRealClass.expects(:after_schedule_example).never
    SomeRealClass.expects(:before_recurring_example).never
    SomeRealClass.expects(:after_recurring_example).never
  end

  test 'handle_delayed_items runs only before_delayed_enqueue' do
    Resque.enqueue_at(future_time, SomeRealClass, 'foo')
    expect_only_delayed_enqueue_hooks

    Resque::Scheduler.handle_delayed_items(future_time)

    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['foo'] }], enqueued
  end

  test 'enqueue_next_item runs only before_delayed_enqueue' do
    Resque.enqueue_at(future_time, SomeRealClass, 'foo')
    expect_only_delayed_enqueue_hooks

    Resque::Scheduler.enqueue_next_item(future_time)

    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['foo'] }], enqueued
  end

  test 'enqueue_delayed runs only before_delayed_enqueue' do
    Resque.enqueue_at(future_time, SomeRealClass, 'foo')
    expect_only_delayed_enqueue_hooks

    assert_equal 1, Resque.enqueue_delayed(SomeRealClass, 'foo')
    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['foo'] }], enqueued
  end

  test 'enqueue_delayed_with_queue runs only before_delayed_enqueue' do
    Resque.enqueue_at_with_queue(SomeRealClass.queue, future_time, SomeRealClass, 'foo')
    expect_only_delayed_enqueue_hooks

    assert_equal 1, Resque.enqueue_delayed_with_queue(SomeRealClass, SomeRealClass.queue, 'foo')
    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['foo'] }], enqueued
  end
end

context 'recurring job hooks' do
  include HookTestHelper

  setup do
    Resque::Scheduler.quiet = true
    Resque.data_store.redis.flushall
    Resque::Scheduler.stubs(:am_master).returns(true)
  end

  def config
    {
      'cron' => '* * * * *',
      'class' => 'SomeRealClass',
      'args' => '/tmp'
    }
  end

  def enqueue_recurring(job_config = config)
    Resque::Scheduler.send(:enqueue_recurring, 'some_job', job_config)
  end

  test 'before_recurring and after_recurring hooks are called' do
    SomeRealClass.expects(:before_recurring_example).with('/tmp')
    SomeRealClass.expects(:after_recurring_example).with('/tmp')

    enqueue_recurring

    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['/tmp'] }], enqueued
  end

  test 'any before_recurring returning false will halt the job from being enqueued' do
    SomeRealClass.expects(:before_recurring_a).with('/tmp').returns(false)
    SomeRealClass.expects(:before_recurring_b).with('/tmp')
    SomeRealClass.expects(:after_recurring_example).never

    enqueue_recurring

    assert_equal [], enqueued
  end

  test 'schedule and delayed hooks are not called' do
    SomeRealClass.expects(:before_schedule_example).never
    SomeRealClass.expects(:after_schedule_example).never
    SomeRealClass.expects(:before_delayed_enqueue_example).never

    enqueue_recurring

    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['/tmp'] }], enqueued
  end

  test 'failure hooks are called when a before_recurring hook raises' do
    e = RuntimeError.new('custom error')
    SomeRealClass.expects(:before_recurring_example).raises(e)
    Resque::Scheduler::FailureHandler.expects(:on_enqueue_failure).with(config, e)

    enqueue_recurring

    assert_equal [], enqueued
  end

  test 'failure hooks are called when an after_recurring hook raises' do
    e = RuntimeError.new('custom error')
    SomeRealClass.expects(:after_recurring_example).raises(e)
    Resque::Scheduler::FailureHandler.expects(:on_enqueue_failure).with(config, e)

    enqueue_recurring

    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['/tmp'] }], enqueued
  end

  test 'recurring hooks are not called for a custom job class' do
    SomeRealClass.expects(:before_recurring_example).never
    SomeRealClass.expects(:after_recurring_example).never
    FakeCustomJobClass.expects(:scheduled).with(SomeRealClass.queue, 'SomeRealClass', '/tmp')

    enqueue_recurring(config.merge('custom_job_class' => 'FakeCustomJobClass'))
  end
end
