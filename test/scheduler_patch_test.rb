# vim:fileencoding=utf-8
require_relative 'test_helper'
require 'resque/scheduler_patch'

context 'Resque::SchedulerPatch' do
  setup do
    Resque::Scheduler.clear_schedule!
    Resque::Scheduler.configure do |c|
      c.dynamic = false
      c.quiet = true
      c.poll_sleep_amount = nil
    end

    @scheduler = Resque::Scheduler.dup
    @scheduler.singleton_class.prepend(Resque::SchedulerPatch)
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

  test 'can enqueue into new queue format' do
    t = Time.now + 60 # in the future
    Resque.enqueue_at(t, Job, 1)
    Resque.enqueue_at(t, Job, 2)

    assert_equal 0, @scheduler.old_resque.delayed_queue_schedule_size
    assert_equal 0, @scheduler.old_resque.delayed_timestamp_size(t)

    # the jobs are in the new queue format
    assert_equal 2, Resque.delayed_queue_schedule_size

    @scheduler.handle_delayed_items(t)

    assert_equal 0, Resque.delayed_queue_schedule_size

    drain_resque(:ivar)
    assert_equal [1,2], Job.run_queue
  end

  test 'reads from old format before new one' do
    t = Time.now + 60 # in the future
    @scheduler.old_resque.enqueue_at(t, Job, 1)
    @scheduler.old_resque.enqueue_at(t, Job, 2)

    expected_queue = [
      {"args"=>[1], "class"=>"Job", "queue"=>"ivar"},
      {"args"=>[2], "class"=>"Job", "queue"=>"ivar"}
    ]

    # we only have one entry in the timestamps queue
    assert_equal 1, @scheduler.old_resque.delayed_queue_schedule_size
    assert_equal 2, @scheduler.old_resque.delayed_timestamp_size(t)
    assert_equal expected_queue, @scheduler.old_resque.delayed_timestamp_peek(t, 0, 2)

    Resque.enqueue_at(t, Job, 3)
    Resque.enqueue_at(t, Job, 4)

    # only pushes to the new style
    assert_equal 1, Resque.redis.zcard(:delayed_queue_schedule)
    assert_equal 2, Resque.delayed_queue_schedule_size

    # Check that next job is from old first
    @scheduler.handle_delayed_items(t)

    assert_equal 0, Resque.delayed_queue_schedule_size
    assert_equal 0, Resque.redis.zcard(:delayed_queue_schedule)

    drain_resque(:ivar)
    assert_equal [1,2,3,4], Job.run_queue
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
