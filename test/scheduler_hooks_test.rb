# vim:fileencoding=utf-8
require_relative 'test_helper'

context 'scheduling jobs with hooks' do
  setup { Resque.data_store.redis.flushall }

  def config
    {
      'cron' => '* * * * *',
      'class' => 'SomeRealClass',
      'args' => '/tmp'
    }
  end

  # helper to inspect the queue
  def enqueued
    Resque.redis.lrange("queue:#{SomeRealClass.queue}", 0, -1).map(&JSON.method(:parse))
  end

  test 'before_schedule and after_scheduler hooks are called when enqueued from config' do
    SomeRealClass.expects(:before_schedule_example).with('/tmp')
    SomeRealClass.expects(:after_schedule_example).with('/tmp')
    Resque::Scheduler.enqueue(config)

    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['/tmp'] }], enqueued
  end

  test 'any before_schedule returning false will halt the job from being enqueued' do
    SomeRealClass.expects(:before_schedule_a).with('/tmp').returns(false)
    SomeRealClass.expects(:before_schedule_b).with('/tmp')
    SomeRealClass.expects(:after_schedule_example).never
    Resque::Scheduler.enqueue(config)

    assert_equal [], enqueued
  end

  test 'before_schedule hook that does not return false should be enqueued' do
    enqueue_time = Time.now + 1
    SomeRealClass.expects(:before_schedule_example).with(:foo)
    SomeRealClass.expects(:after_schedule_example).with(:foo)
    Resque.enqueue_at(enqueue_time.to_i, SomeRealClass, :foo)
    assert_equal(1, Resque.delayed_timestamp_size(enqueue_time.to_i),
                 'job should be enqueued')
  end

  test 'before_schedule hook that returns false should not be enqueued' do
    enqueue_time = Time.now + 1
    SomeRealClass.expects(:before_schedule_example).with(:foo).returns(false)
    SomeRealClass.expects(:after_schedule_example).never
    Resque.enqueue_at(enqueue_time.to_i, SomeRealClass, :foo)
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
