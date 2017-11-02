# vim:fileencoding=utf-8
require_relative 'test_helper'
require 'resque/scheduler_revert_migrator'
require 'resque/scheduler_patch'

context 'Resque::SchedulerRevertMigrator' do
  setup do
    Resque::Scheduler.clear_schedule!
    Resque::Scheduler.configure do |c|
      c.dynamic = false
      c.quiet = true
      c.poll_sleep_amount = nil
    end

    @patched_scheduler = Resque::Scheduler.dup
    @patched_scheduler.singleton_class.prepend(Resque::SchedulerPatch)
    Job.run_queue = []
  end

  teardown do
    Resque.redis.redis.flushall
  end

  class Job
    @queue = :ivar

    def self.run_queue=(o)
      @run_queue = o
    end

    def self.run_queue
      @run_queue
    end

    def self.perform(id)
      self.run_queue << id
    end
  end

  test 'migrates new format to old one' do
    t = Time.now + 60 # in the future
    Resque.enqueue_at(t, Job, 1)
    Resque.enqueue_at(t, Job, 2)

    assert_equal 2, Resque.delayed_queue_schedule_size
    assert_equal 0, Resque.redis.zcard('delayed_queue_schedule')
    assert_equal 0, Resque.redis.llen("delayed:#{t.to_i}")

    Resque::SchedulerRevertMigrator.revert_migrate

    assert_equal 1, Resque.redis.zcard('delayed_queue_schedule')
    assert_equal 2, Resque.redis.llen("delayed:#{t.to_i}")

    @patched_scheduler.handle_delayed_items(t)

    drain_resque(:ivar)

    assert_equal 0, Resque.delayed_queue_schedule_size
    assert_equal [1, 2], Job.run_queue
  end

  test 'migrates hybrid schedules to new format' do
    t = Time.now + 60 # in the future

    Resque::SchedulerRevertMigrator.old_resque.enqueue_at(t - 10, Job, 1)
    Resque::SchedulerRevertMigrator.old_resque.enqueue_at(t - 10, Job, 2)

    Resque.enqueue_at(t, Job, 3)
    Resque.enqueue_at(t, Job, 4)

    Resque::SchedulerRevertMigrator.old_resque.enqueue_at(t + 10, Job, 5)
    Resque::SchedulerRevertMigrator.old_resque.enqueue_at(t + 10, Job, 6)

    assert_equal 2, Resque.redis.zcard('delayed_queue_schedule')

    assert_equal 2, Resque.delayed_queue_schedule_size

    Resque::SchedulerRevertMigrator.revert_migrate

    assert_equal 3, Resque.redis.zcard('delayed_queue_schedule')
    assert_equal 0, Resque.delayed_queue_schedule_size

    @patched_scheduler.handle_delayed_items(t + 10)
    drain_resque(:ivar)

    assert_equal [1, 2, 3, 4, 5, 6], Job.run_queue
  end

  private

  def drain_resque(queue)
    job = Resque.reserve(queue)

    while job
      job.perform
      job = Resque.reserve(queue)
    end
  end
end
