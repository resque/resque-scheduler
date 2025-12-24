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

  # helper to inspected the queue
  def enqueued
    Resque.redis.lrange("queue:#{SomeRealClass.queue}", 0, -1).map(&JSON.method(:parse))
  end

  test 'direct enqueue does not trigger schedule hooks' do
    SomeRealClass.expects(:before_schedule_example).never
    SomeRealClass.expects(:after_schedule_example).never
    Resque::Scheduler.enqueue(config)

    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['/tmp'] }], enqueued
  end

  test 'direct enqueue bypasses before_schedule hooks so job cannot be halted' do
    SomeRealClass.expects(:before_schedule_a).never
    SomeRealClass.expects(:before_schedule_b).never
    SomeRealClass.expects(:after_schedule_example).never
    Resque::Scheduler.enqueue(config)

    # Job is enqueued because schedule hooks are not run for direct enqueue
    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['/tmp'] }], enqueued
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
  setup do
    Resque::Scheduler.quiet = true
    Resque.data_store.redis.flushall
  end

  test 'schedule hooks are not called again when delayed job is transferred to queue' do
    future_time = Time.now + 600

    # Hooks should be called when the job is initially scheduled
    SomeRealClass.expects(:before_schedule_example).with('foo')
    SomeRealClass.expects(:after_schedule_example).with('foo')
    Resque.enqueue_at(future_time, SomeRealClass, 'foo')

    # When the job is transferred from delayed queue to actual queue,
    # schedule hooks should NOT be called again
    SomeRealClass.expects(:before_schedule_example).never
    SomeRealClass.expects(:after_schedule_example).never
    Resque::Scheduler.handle_delayed_items(future_time)
  end

  test 'before_delayed_enqueue is called when delayed job is transferred to queue' do
    future_time = Time.now + 600

    # Schedule the job (schedule hooks called here)
    SomeRealClass.stubs(:before_schedule_example)
    SomeRealClass.stubs(:after_schedule_example)
    Resque.enqueue_at(future_time, SomeRealClass, 'foo')

    # before_delayed_enqueue should be called when transferring to actual queue
    # Note: args come back as strings after JSON serialization
    SomeRealClass.expects(:before_delayed_enqueue_example).with('foo').once

    Resque::Scheduler.handle_delayed_items(future_time)
  end
end

context 'cron job hooks' do
  def config
    {
      'cron' => '* * * * *',
      'class' => 'SomeRealClass',
      'args' => '/tmp'
    }
  end

  def enqueued
    Resque.redis.lrange("queue:#{SomeRealClass.queue}", 0, -1).map(&JSON.method(:parse))
  end

  setup do
    Resque::Scheduler.quiet = true
    Resque.data_store.redis.flushall
    Resque::Scheduler.stubs(:am_master).returns(true)
  end

  test 'cron job triggers schedule hooks via enqueue_recurring' do
    SomeRealClass.expects(:before_schedule_example).with('/tmp')
    SomeRealClass.expects(:after_schedule_example).with('/tmp')

    Resque::Scheduler.send(:enqueue_recurring, 'some_job', config)

    assert_equal [{ 'class' => 'SomeRealClass', 'args' => ['/tmp'] }], enqueued
  end

  test 'cron job before_schedule returning false halts the job' do
    SomeRealClass.expects(:before_schedule_example).with('/tmp').returns(false)
    SomeRealClass.expects(:after_schedule_example).never

    Resque::Scheduler.send(:enqueue_recurring, 'some_job', config)

    assert_equal [], enqueued
  end
end
