# vim:fileencoding=utf-8
require_relative 'test_helper'
require 'resque/scheduler_patch'

context 'Resque::SchedulerPatch' do
  setup do
    Resque::Scheduler.configure do |c|
      c.dynamic = false
      c.quiet = true
      c.env = nil
      c.app_name = nil
    end
    Resque.redis.flushall
    Resque::Scheduler.clear_schedule!
    Resque::Scheduler.send(:instance_variable_set, :@scheduled_jobs, {})
    Resque::Scheduler.send(:instance_variable_set, :@shutdown, false)

    @scheduler = Resque::Scheduler.dup
    @scheduler.singleton_class.prepend(Resque::SchedulerPatch)
  end
  require 'byebug'

  test 'can enqueue into new queue format' do
    t = Time.now + 60 # in the future
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t, SomeIvarJob)
    @scheduler.handle_delayed_items(t)

    assert_equal 0, Resque.delayed_queue_schedule_size
  end

  test 'reads from old format before new one' do
    t = Time.now + 60 # in the future
    @scheduler.old_resque.enqueue_at(t, SomeIvarJob)
    @scheduler.old_resque.enqueue_at(t, SomeIvarJob)

    assert_equal 1, Resque.redis.zcard(:delayed_queue_schedule)

    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t, SomeIvarJob)

    assert_equal 2, Resque.delayed_queue_schedule_size

    # Check that next job is from old first
    @scheduler.handle_delayed_items(t)

    assert_equal 0, Resque.delayed_queue_schedule_size
    assert_equal 0, Resque.redis.zcard(:delayed_queue_schedule)
  end
end
