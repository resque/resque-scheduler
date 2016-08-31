# vim:fileencoding=utf-8

require_relative 'test_helper'

context 'ScheduledJobMigrator' do
  setup do
    Resque::Scheduler.quiet = true
    Resque.redis.flushall
    @from_redis = 'localhost:6379:0'
    @to_redis = 'localhost:6379:1'
  end

  test 'migrate! moves jobs to other database when jobs are at the same timestamp' do
    Resque.redis = @from_redis

    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeIvarJob, 'foo2')

    migrator = Resque::Scheduler::ScheduledJobMigrator.new(@from_redis, @to_redis)
    migrator.migrate!

    Resque.redis = @to_redis

    assert_equal(2, Resque.count_all_scheduled_jobs)
    assert_equal(
      [
        { 'args' => ['foo'], 'class' => 'SomeIvarJob', 'queue' => 'ivar' },
        { 'args' => ['foo2'], 'class' => 'SomeIvarJob', 'queue' => 'ivar' }
      ], Resque.delayed_timestamp_peek(t, 0, 2)
    )
  end

  test 'migrate! will move jobs at various timestamps to the other database' do
    @from_redis = 'localhost:6379:0'
    @to_redis = 'localhost:6379:1'

    Resque.redis = @from_redis

    t = Time.now + 120
    t2 = Time.now + 122
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t2, SomeIvarJob, 'foo2')

    migrator = Resque::Scheduler::ScheduledJobMigrator.new(@from_redis, @to_redis)
    migrator.migrate!

    Resque.redis = @to_redis

    assert_equal(2, Resque.count_all_scheduled_jobs)
    assert_equal(
      [{ 'args' => ['foo'], 'class' => 'SomeIvarJob', 'queue' => 'ivar' }],
      Resque.delayed_timestamp_peek(t, 0, 1)
    )
    assert_equal(
      [{ 'args' => ['foo2'], 'class' => 'SomeIvarJob', 'queue' => 'ivar' }],
      Resque.delayed_timestamp_peek(t2, 0, 1)
    )
  end

  test 'migrate! works when there are no jobs' do
    @from_redis = 'localhost:6379:0'
    @to_redis = 'localhost:6379:1'

    migrator = Resque::Scheduler::ScheduledJobMigrator.new(@from_redis, @to_redis)
    migrator.migrate!
  end
end
