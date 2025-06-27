# vim:fileencoding=utf-8
require_relative 'test_helper'

def assert_resque_key_exists?(key)
  if Gem::Requirement.create('< 4').satisfied_by?(Gem::Version.create(Redis::VERSION))
    assert(!Resque.redis.exists(key))
  else
    assert(!Resque.redis.exists?(key))
  end
end

context 'DelayedQueue' do
  setup do
    Resque::Scheduler.quiet = true
    Resque.data_store.redis.flushall
  end

  test 'enqueue_at adds correct list and zset' do
    timestamp = Time.now + 1
    encoded_job = Resque.encode(
      class: SomeIvarJob.to_s,
      args: ['path'],
      queue: Resque.queue_from_class(SomeIvarJob)
    )

    assert_equal(0, Resque.redis.llen("delayed:#{timestamp.to_i}").to_i,
                 'delayed queue should be empty to start')
    assert_equal(0, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps set should be empty to start')

    Resque.enqueue_at(timestamp, SomeIvarJob, 'path')

    # Confirm the correct keys were added
    assert_equal(1, Resque.redis.llen("delayed:#{timestamp.to_i}").to_i,
                 'delayed queue should have one entry now')
    assert_equal(1, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps should have one entry now')
    assert_equal(1, Resque.redis.zcard(:delayed_queue_schedule),
                 'The delayed_queue_schedule should have 1 entry now')

    read_timestamp = timestamp.to_i

    item = Resque.next_item_for_timestamp(read_timestamp)

    # Confirm the item came out correctly
    assert_equal('SomeIvarJob', item['class'],
                 'Should be the same class that we queued')
    assert_equal(['path'], item['args'],
                 'Should have the same arguments that we queued')

    # And now confirm the keys are gone
    assert_resque_key_exists?("delayed:#{timestamp.to_i}")
    assert_equal(0, Resque.redis.zcard(:delayed_queue_schedule),
                 'delayed queue should be empty')
    assert_equal(0, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps set should be empty')
  end

  test 'enqueue_at with queue adds correct list and zset and queue' do
    timestamp = Time.now + 1
    encoded_job = Resque.encode(
      class: SomeIvarJob.to_s,
      args: ['path'],
      queue: 'critical'
    )

    assert_equal(0, Resque.redis.llen("delayed:#{timestamp.to_i}").to_i,
                 'delayed queue should be empty to start')
    assert_equal(0, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps set should be empty to start')

    Resque.enqueue_at_with_queue('critical', timestamp, SomeIvarJob, 'path')

    # Confirm the correct keys were added
    assert_equal(1, Resque.redis.llen("delayed:#{timestamp.to_i}").to_i,
                 'delayed queue should have one entry now')
    assert_equal(1, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps should have one entry now')
    assert_equal(1, Resque.redis.zcard(:delayed_queue_schedule),
                 'The delayed_queue_schedule should have 1 entry now')

    read_timestamp = timestamp.to_i

    item = Resque.next_item_for_timestamp(read_timestamp)

    # Confirm the item came out correctly
    assert_equal('SomeIvarJob', item['class'],
                 'Should be the same class that we queued')
    assert_equal(['path'], item['args'],
                 'Should have the same arguments that we queued')
    assert_equal('critical', item['queue'],
                 'Should have the queue that we asked for')

    # And now confirm the keys are gone
    assert_resque_key_exists?("delayed:#{timestamp.to_i}")
    assert_equal(0, Resque.redis.zcard(:delayed_queue_schedule),
                 'delayed queue should be empty')
    assert_equal(0, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps set should be empty')
  end

  test "a job in the future doesn't come out" do
    timestamp = Time.now + 600
    encoded_job = Resque.encode(
      class: SomeIvarJob.to_s,
      args: ['path'],
      queue: Resque.queue_from_class(SomeIvarJob)
    )

    assert_equal(0, Resque.redis.llen("delayed:#{timestamp.to_i}").to_i,
                 'delayed queue should be empty to start')
    assert_equal(0, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps set should be empty to start')

    Resque.enqueue_at(timestamp, SomeIvarJob, 'path')

    # Confirm the correct keys were added
    assert_equal(1, Resque.redis.llen("delayed:#{timestamp.to_i}").to_i,
                 'delayed queue should have one entry now')
    assert_equal(1, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps should have one entry now')
    assert_equal(1, Resque.redis.zcard(:delayed_queue_schedule),
                 'The delayed_queue_schedule should have 1 entry now')

    read_timestamp = Resque.next_delayed_timestamp

    assert_nil(read_timestamp, 'No timestamps should be ready for queueing')
  end

  test 'a job in the future comes out if you want it to' do
    timestamp = Time.now + 600 # 10 minutes from now

    Resque.enqueue_at(timestamp, SomeIvarJob, 'path')

    read_timestamp = Resque.next_delayed_timestamp(timestamp)

    assert_equal(timestamp.to_i, read_timestamp,
                 'The timestamp we pull out of redis should match the ' \
                 'one we put in')
  end

  test 'enqueue_at and enqueue_in are equivalent' do
    timestamp = Time.now + 60
    encoded_job = Resque.encode(
      class: SomeIvarJob.to_s,
      args: ['path'],
      queue: Resque.queue_from_class(SomeIvarJob)
    )

    Resque.enqueue_at(timestamp, SomeIvarJob, 'path')
    Resque.enqueue_in(timestamp - Time.now, SomeIvarJob, 'path')

    assert_equal(1, Resque.redis.zcard(:delayed_queue_schedule),
                 'should have one timestamp in the delayed queue')
    assert_equal(2, Resque.redis.llen("delayed:#{timestamp.to_i}"),
                 'should have 2 items in the timestamp queue')
    assert_equal(1, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps should have one entry now')
  end

  test 'delay_or_enqueue_at enqueues a job when none match' do
    timestamp = Time.now + 600 # 10 minutes from now
    encoded_job = Resque.encode(
      class: SomeIvarJob.to_s,
      args: ['path'],
      queue: Resque.queue_from_class(SomeIvarJob)
    )

    assert_equal(0, Resque.redis.llen("delayed:#{timestamp.to_i}").to_i,
                 'delayed queue should be empty to start')
    assert_equal(0, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps set should be empty to start')

    Resque.delay_or_enqueue_at(timestamp, SomeIvarJob, 'path')

    # Confirm the correct keys were added
    assert_equal(1, Resque.redis.llen("delayed:#{timestamp.to_i}").to_i,
                 'delayed queue should have one entry now')
    assert_equal(1, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps should have one entry now')
    assert_equal(1, Resque.redis.zcard(:delayed_queue_schedule),
                 'The delayed_queue_schedule should have 1 entry now')
  end

  test 'delay_or_enqueue_at updates the timestamp for a matching job' do
    timestamp = Time.now + 600 # 10 minutes from now
    encoded_job = Resque.encode(
      class: SomeIvarJob.to_s,
      args: ['path'],
      queue: Resque.queue_from_class(SomeIvarJob)
    )

    Resque.enqueue_at(timestamp, SomeIvarJob, 'path')

    assert_equal(1, Resque.redis.llen("delayed:#{timestamp.to_i}").to_i,
                 'delayed queue should have one entry now')
    assert_equal(1, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps should have one entry now')

    new_timestamp = Time.now + 700
    assert_equal(1,
                 Resque.delay_or_enqueue_at(new_timestamp, SomeIvarJob, 'path'))
    assert_equal(1, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps should still have only 1 entry')

    assert_equal(0, Resque.redis.llen("delayed:#{timestamp.to_i}").to_i,
                 'delayed queue no longer has old entry')
    assert_equal(1, Resque.redis.llen("delayed:#{new_timestamp.to_i}").to_i,
                 'delayed queue should have new entry')
  end

  test 'delay_or_enqueue_at updates multiple matching jobs' do
    encoded_job = Resque.encode(
      class: SomeIvarJob.to_s,
      args: ['path'],
      queue: Resque.queue_from_class(SomeIvarJob)
    )

    Resque.enqueue_at(Time.now + 600, SomeIvarJob, 'path')
    Resque.enqueue_at(Time.now + 660, SomeIvarJob, 'path')

    assert_equal(2, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps should have two entries now')

    new_timestamp = Time.now + 1200
    assert_equal(2,
                 Resque.delay_or_enqueue_at(new_timestamp, SomeIvarJob, 'path'),
                 'should have updated two jobs')
    assert_equal(1, Resque.redis.scard("timestamps:#{encoded_job}"),
                 'job timestamps should have one entry now')
    assert_equal(2, Resque.redis.llen("delayed:#{new_timestamp.to_i}").to_i,
                 'delayed queue should have two entries')
  end

  test 'empty delayed_queue_peek returns empty array' do
    assert_equal([], Resque.delayed_queue_peek(0, 20))
  end

  test 'delayed_queue_peek returns stuff' do
    t = Time.now
    expected_timestamps = (1..5).to_a.map do |i|
      (t + 60 + i).to_i
    end

    expected_timestamps.each do |timestamp|
      Resque.delayed_push(timestamp, class: SomeIvarJob, args: 'blah1 ')
    end

    timestamps = Resque.delayed_queue_peek(1, 2)

    assert_equal(expected_timestamps[1, 2], timestamps)
  end

  test 'delayed_queue_schedule_size returns correct size' do
    assert_equal(0, Resque.delayed_queue_schedule_size)
    Resque.enqueue_at(Time.now + 60, SomeIvarJob)
    assert_equal(1, Resque.delayed_queue_schedule_size)
  end

  test 'delayed_timestamp_size returns 0 when nothing is queue' do
    t = Time.now + 60
    assert_equal(0, Resque.delayed_timestamp_size(t))
  end

  test 'delayed_timestamp_size returns 1 when one thing is queued' do
    t = Time.now + 60
    Resque.enqueue_at(t, SomeIvarJob)
    assert_equal(1, Resque.delayed_timestamp_size(t))
  end

  test 'delayed_timestamp_peek returns empty array when nothings in it' do
    t = Time.now + 60
    assert_equal([], Resque.delayed_timestamp_peek(t, 0, 1),
                 "make sure it's an empty array, not nil")
  end

  test 'delayed_timestamp_peek returns an array containing one job ' \
       'when one thing is queued' do
    t = Time.now + 60
    Resque.enqueue_at(t, SomeIvarJob)
    assert_equal(
      [{ 'args' => [], 'class' => 'SomeIvarJob', 'queue' => 'ivar' }],
      Resque.delayed_timestamp_peek(t, 0, 1)
    )
  end

  test 'delayed_timestamp_peek returns an array of multiple jobs ' \
       'when more than one job is queued' do
    t = Time.now + 60
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t, SomeIvarJob)
    job = { 'args' => [], 'class' => 'SomeIvarJob', 'queue' => 'ivar' }
    assert_equal([job, job], Resque.delayed_timestamp_peek(t, 0, 2))
  end

  test 'delayed_timestamp_peek only returns an array of one job ' \
       'if only asked for 1' do
    t = Time.now + 60
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t, SomeIvarJob)
    job = { 'args' => [], 'class' => 'SomeIvarJob', 'queue' => 'ivar' }
    assert_equal([job], Resque.delayed_timestamp_peek(t, 0, 1))
  end

  test 'handle_delayed_items with no items' do
    Resque::Scheduler.expects(:enqueue).never
    Resque::Scheduler.handle_delayed_items
  end

  test 'handle_delayed_item with items' do
    t = Time.now - 60 # in the past

    # 2 SomeIvarJob jobs should be created in the "ivar" queue
    Resque::Job.expects(:create).twice.with(:ivar, SomeIvarJob)
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t, SomeIvarJob)
  end

  test 'handle_delayed_items with items in the future' do
    t = Time.now + 60 # in the future
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t, SomeIvarJob)

    # 2 SomeIvarJob jobs should be created in the "ivar" queue
    Resque::Job.expects(:create).twice.with('ivar', SomeIvarJob, nil)
    Resque::Scheduler.handle_delayed_items(t)
  end

  test 'calls klass#scheduled when enqueuing jobs if it exists' do
    t = Time.now - 60
    data_hash = { foo: 'bar' }
    FakeCustomJobClassEnqueueAt.expects(:scheduled).once.with(
      :test,
      FakeCustomJobClassEnqueueAt.to_s,
      data_hash
    )
    Resque.enqueue_at(t, FakeCustomJobClassEnqueueAt, foo: 'bar')
  end

  test 'when Resque.inline = true, calls klass#scheduled ' \
       'when enqueuing jobs if it exists' do
    old_val = Resque.inline
    begin
      Resque.inline = true
      t = Time.now - 60
      data_hash = { foo: 'bar' }
      FakeCustomJobClassEnqueueAt.expects(:scheduled).once.with(
        :test,
        FakeCustomJobClassEnqueueAt.to_s,
        data_hash
      )
      Resque.enqueue_at(t, FakeCustomJobClassEnqueueAt, foo: 'bar')
    ensure
      Resque.inline = old_val
    end
  end

  test 'when Resque.inline = true, calls Resque#enqueue ' \
       'when klass#scheduled is not defined' do
    old_val = Resque.inline
    begin
      Resque.inline = true
      assert_false(SomeFancyJob.respond_to?(:scheduled))
      Resque.expects(:enqueue_to).with(:fancy, SomeFancyJob, 'foo', 'bar')
      Resque.enqueue_at(Time.now + 10, SomeFancyJob, 'foo', 'bar')
    ensure
      Resque.inline = old_val
    end
  end

  test 'enqueue_at calls Resque#enqueue when given a moment in the past' \
       'when klass#scheduled is not defined' do
    assert_false(SomeFancyJob.respond_to?(:scheduled))
    Resque.expects(:enqueue_to).with(:fancy, SomeFancyJob, 'foo', 'bar')
    Resque.enqueue_at(Time.now - 10, SomeFancyJob, 'foo', 'bar')
  end

  test 'enqueue_at calls Resque#enqueue when given the current time' do
    Timecop.freeze do
      Resque.expects(:enqueue_to).with(:fancy, SomeFancyJob, 'foo', 'bar')
      Resque.enqueue_at(Time.now, SomeFancyJob, 'foo', 'bar')
    end
  end

  test 'enqueue_next_item picks one job' do
    t = Time.now + 60

    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t, SomeIvarJob)
    Resque::Scheduler.enqueue_next_item(t)
    assert_equal(1, Resque.delayed_timestamp_peek(t, 0, 3).length)
  end

  context "non-batch delayed item queue" do
    batch_disabled = Resque::Scheduler.disable_delayed_requeue_batches
    batch_size = Resque::Scheduler.delayed_requeue_batch_size
    setup do
      Resque::Scheduler.quiet = true
      Resque.data_store.redis.flushall
      Resque::Scheduler.disable_delayed_requeue_batches = true
      Resque::Scheduler.delayed_requeue_batch_size = 1
    end

    teardown do
      Resque::Scheduler.disable_delayed_requeue_batches = batch_disabled
      Resque::Scheduler.delayed_requeue_batch_size = batch_size
    end

    test 'enqueue_delayed_items_for_timestamp enqueues jobs for the timestamp' do
      t = Time.now + 60

      Resque::Scheduler.expects(:enqueue_items_in_batch_for_timestamp).never

      # create 90 jobs
      90.times { Resque.enqueue_at(t, SomeIvarJob) }
      assert_equal(90, Resque.delayed_timestamp_size(t))

      Resque::Scheduler.enqueue_delayed_items_for_timestamp(t)
      assert_equal(0, Resque.delayed_timestamp_size(t))

      # assert that the active queue is now 90
      assert_equal(90, Resque.size(Resque.queue_from_class(SomeIvarJob)))
    end

    # TODO clean up timestamp tests?
  end

  context "batch delayed item queue" do
    batch_disabled = Resque::Scheduler.disable_delayed_requeue_batches
    batch_size = Resque::Scheduler.delayed_requeue_batch_size
    setup do
      Resque::Scheduler.quiet = true
      Resque.data_store.redis.flushall
      Resque::Scheduler.disable_delayed_requeue_batches = false
      Resque::Scheduler.delayed_requeue_batch_size = 100
    end

    teardown do
      Resque::Scheduler.disable_delayed_requeue_batches = batch_disabled
      Resque::Scheduler.delayed_requeue_batch_size = batch_size
    end

    test 'enqueue_delayed_items_for_timestamp enqueues jobs in 2 batches' do
      t = Time.now + 60

      Resque::Scheduler.expects(:enqueue_next_item).never

      # create 120 jobs
      120.times { Resque.enqueue_at(t, SomeIvarJob) }
      assert_equal(120, Resque.delayed_timestamp_size(t))

      Resque::Scheduler.enqueue_delayed_items_for_timestamp(t)
      assert_equal(0, Resque.delayed_timestamp_size(t))

      # assert that the active queue is now 120
      assert_equal(120, Resque.size(Resque.queue_from_class(SomeIvarJob)))
    end

    test 'enqueue_delayed_items_for_timestamp enqueues jobs in one batch for the timestamp' do
      t = Time.now + 60

      Resque::Scheduler.expects(:enqueue_next_item).never

      # create 90 jobs
      90.times { Resque.enqueue_at(t, SomeIvarJob) }
      assert_equal(90, Resque.delayed_timestamp_size(t))

      Resque::Scheduler.enqueue_delayed_items_for_timestamp(t)
      assert_equal(0, Resque.delayed_timestamp_size(t))

      # assert that the active queue is now 90
      assert_equal(90, Resque.size(Resque.queue_from_class(SomeIvarJob)))
    end

    # test to make sure the timestamp is cleaned up

    test 'enqueue_delayed_items_for_timestamp handles a watch failure' do
      t = Time.now + 60

      # create 100 jobs
      100.times { Resque.enqueue_at(t, SomeIvarJob) }
      assert_equal(100, Resque.delayed_timestamp_size(t))

      Resque.redis.stubs(:watch).returns(nil)

      Resque.expects(:clean_up_timestamp).never

      Resque::Scheduler.enqueue_delayed_items_for_timestamp(t)
    end

    test 'enqueue_delayed_items_for_timestamp cleans up a timestamp' do
      t = Time.now + 60

      # create 100 jobs
      100.times { Resque.enqueue_at(t, SomeIvarJob) }
      assert_equal(100, Resque.delayed_timestamp_size(t))

      Resque.expects(:clean_up_timestamp).once

      Resque::Scheduler.enqueue_delayed_items_for_timestamp(t)
    end

  end

  test 'enqueue_delayed_items_for_timestamp creates jobs ' \
       'and empties the delayed queue' do
    t = Time.now + 60

    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t, SomeIvarJob)

    # 2 SomeIvarJob jobs should be created in the "ivar" queue
    Resque::Job.expects(:create).twice.with('ivar', SomeIvarJob, nil)

    Resque::Scheduler.enqueue_delayed_items_for_timestamp(t)

    # delayed queue for timestamp should be empty
    assert_equal(0, Resque.delayed_timestamp_peek(t, 0, 3).length)
  end

  test 'enqueue_delayed creates jobs and empties the delayed queue' do
    t = Time.now + 60

    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeIvarJob, 'bar')
    Resque.enqueue_at(t, SomeIvarJob, 'bar')

    # 3 SomeIvarJob jobs should be created in the "ivar" queue
    Resque::Job.expects(:create).never.with(:ivar, SomeIvarJob, 'foo')
    Resque::Job.expects(:create).twice.with(:ivar, SomeIvarJob, 'bar')

    # 2 SomeIvarJob jobs should be enqueued
    assert_equal(2, Resque.enqueue_delayed(SomeIvarJob, 'bar'))

    # delayed queue for timestamp should have one remaining
    assert_equal(1, Resque.delayed_timestamp_peek(t, 0, 3).length)
  end

  test 'handle_delayed_items works with out specifying queue ' \
       '(upgrade case)' do
    t = Time.now - 60
    Resque.delayed_push(t, class: 'SomeIvarJob')

    # Since we didn't specify :queue when calling delayed_push, it will be
    # forced to load the class to figure out the queue.  This is the upgrade
    # case from 1.0.4 to 1.0.5.
    Resque::Job.expects(:create).once.with(:ivar, SomeIvarJob, nil)

    Resque::Scheduler.handle_delayed_items
  end

  test 'reset_delayed_queue clears the queue' do
    t = Time.now + 120
    4.times { Resque.enqueue_at(t, SomeIvarJob) }
    4.times { Resque.enqueue_at(Time.now + rand(100), SomeIvarJob) }

    Resque.reset_delayed_queue
    assert_equal(0, Resque.delayed_queue_schedule_size)
    assert_equal(0, Resque.redis.keys('timestamps:*').size)
  end

  test 'remove_delayed removes job and returns the count' do
    t = Time.now + 120
    encoded_job = Resque.encode(
      class: SomeIvarJob.to_s,
      args: [],
      queue: Resque.queue_from_class(SomeIvarJob)
    )
    Resque.enqueue_at(t, SomeIvarJob)

    assert_equal(1, Resque.remove_delayed(SomeIvarJob))
    assert_equal(0, Resque.redis.scard("timestamps:#{encoded_job}"))
  end

  test "when Resque.inline = true, remove_delayed doesn't remove the job" \
       'and returns 0' do
    begin
      Resque.inline = true

      timestamp = Time.now + 120
      Resque.enqueue_at(timestamp, SomeIvarJob, 'foo', 'bar')

      assert_equal(0, Resque.remove_delayed(SomeIvarJob))
    ensure
      Resque.inline = false
    end
  end

  test 'scheduled_at returns an array containing job schedule time' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)

    assert_equal([t.to_i], Resque.scheduled_at(SomeIvarJob))
  end

  test "remove_delayed doesn't remove things it shouldn't" do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeIvarJob, 'bar')
    Resque.enqueue_at(t, SomeIvarJob, 'bar')
    Resque.enqueue_at(t, SomeIvarJob, 'baz')

    assert_equal(0, Resque.remove_delayed(SomeIvarJob))
  end

  test 'remove_delayed respected param' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeIvarJob, 'bar')
    Resque.enqueue_at(t, SomeIvarJob, 'bar')
    Resque.enqueue_at(t, SomeIvarJob, 'baz')

    assert_equal(2, Resque.remove_delayed(SomeIvarJob, 'bar'))
    assert_equal(1, Resque.delayed_queue_schedule_size)
  end

  test 'remove_delayed removes items in different timestamps' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(2, Resque.remove_delayed(SomeIvarJob, 'bar'))
    assert_equal(2, Resque.count_all_scheduled_jobs)
  end

  test 'remove_delayed_selection removes multiple items matching ' \
       'arguments at same timestamp' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'llama')
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'monkey')
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'platypus')
    Resque.enqueue_at(t, SomeIvarJob, 'baz')
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'llama')
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'llama')

    assert_equal(5, Resque.remove_delayed_selection { |a| a.first == 'bar' })
    assert_equal(2, Resque.count_all_scheduled_jobs)
  end

  test 'remove_delayed_selection removes single item matching arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(1, Resque.remove_delayed_selection { |a| a.first == 'foo' })
    assert_equal(3, Resque.count_all_scheduled_jobs)
  end

  test 'remove_delayed_selection removes multiple items matching arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(2, Resque.remove_delayed_selection { |a| a.first == 'bar' })
    assert_equal(2, Resque.count_all_scheduled_jobs)
  end

  test 'remove_delayed_selection removes multiple items matching ' \
       'arguments as hash' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, foo: 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, foo: 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, foo: 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, foo: 'baz')

    assert_equal(
      2, Resque.remove_delayed_selection { |a| a.first['foo'] == 'bar' }
    )
    assert_equal(2, Resque.count_all_scheduled_jobs)
  end

  test 'remove_delayed_selection ignores jobs with no arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t + 1, SomeIvarJob)
    Resque.enqueue_at(t + 2, SomeIvarJob)
    Resque.enqueue_at(t + 3, SomeIvarJob)

    assert_equal(0, Resque.remove_delayed_selection { |a| a.first == 'bar' })
    assert_equal(4, Resque.count_all_scheduled_jobs)
  end

  test "remove_delayed_selection doesn't remove items it shouldn't" do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(0, Resque.remove_delayed_selection { |a| a.first == 'qux' })
    assert_equal(4, Resque.count_all_scheduled_jobs)
  end

  test 'remove_delayed_selection ignores last_enqueued_at redis key' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.last_enqueued_at(SomeIvarJob.to_s, t.to_s)

    assert_equal(0, Resque.remove_delayed_selection { |a| a.first == 'bar' })
    assert_equal(t.to_s, Resque.get_last_enqueued_at(SomeIvarJob.to_s))
  end

  test 'remove_delayed_selection removes item by class' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, Resque.remove_delayed_selection(SomeIvarJob) do |a|
      a.first == 'foo'
    end)
    assert_equal(1, Resque.count_all_scheduled_jobs)
  end

  test 'remove_delayed_selection removes item by class name as a string' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, Resque.remove_delayed_selection('SomeIvarJob') do |a|
      a.first == 'foo'
    end)
    assert_equal(1, Resque.count_all_scheduled_jobs)
  end

  test 'remove_delayed_selection removes item by class name as a symbol' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, Resque.remove_delayed_selection(:SomeIvarJob) do |a|
      a.first == 'foo'
    end)
    assert_equal(1, Resque.count_all_scheduled_jobs)
  end

  test 'remove_delayed_selection removes items only from matching job class' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 1, SomeQuickJob, 'bar')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 2, SomeQuickJob, 'foo')

    assert_equal(2, Resque.remove_delayed_selection(SomeIvarJob) do |a|
      a.first == 'foo'
    end)
    assert_equal(4, Resque.count_all_scheduled_jobs)
  end

  test 'remove_delayed_selection removes items from matching job class ' \
       'without params' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t + 1, SomeQuickJob)
    Resque.enqueue_at(t + 2, SomeIvarJob)
    Resque.enqueue_at(t + 3, SomeQuickJob)

    assert_equal(2, Resque.remove_delayed_selection(SomeQuickJob) { true })
    assert_equal(2, Resque.count_all_scheduled_jobs)
  end

  test 'enqueue_delayed_selection enqueues multiple items matching ' \
       'arguments at same timestamp' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'llama')
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'monkey')
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'platypus')
    Resque.enqueue_at(t, SomeIvarJob, 'baz')
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'llama')
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'llama')

    assert_equal(5, Resque.enqueue_delayed_selection { |a| a.first == 'bar' })
    assert_equal(2, Resque.count_all_scheduled_jobs)
  end

  test 'enqueue_delayed_selection enqueues single item matching arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(1, Resque.enqueue_delayed_selection { |a| a.first == 'foo' })
    assert_equal(3, Resque.count_all_scheduled_jobs)
  end

  test 'enqueue_delayed_selection enqueues multiple items matching arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(2, Resque.enqueue_delayed_selection { |a| a.first == 'bar' })
    assert_equal(2, Resque.count_all_scheduled_jobs)
  end

  test 'enqueue_delayed_selection enqueues multiple items matching ' \
       'arguments as hash' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, foo: 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, foo: 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, foo: 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, foo: 'baz')

    assert_equal(
      2, Resque.enqueue_delayed_selection { |a| a.first['foo'] == 'bar' }
    )
    assert_equal(2, Resque.count_all_scheduled_jobs)
  end

  test 'enqueue_delayed_selection ignores jobs with no arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t + 1, SomeIvarJob)
    Resque.enqueue_at(t + 2, SomeIvarJob)
    Resque.enqueue_at(t + 3, SomeIvarJob)

    assert_equal(0, Resque.enqueue_delayed_selection { |a| a.first == 'bar' })
    assert_equal(4, Resque.count_all_scheduled_jobs)
  end

  test "enqueue_delayed_selection doesn't enqueue items it shouldn't" do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(0, Resque.enqueue_delayed_selection { |a| a.first == 'qux' })
    assert_equal(4, Resque.count_all_scheduled_jobs)
  end

  test 'enqueue_delayed_selection ignores last_enqueued_at redis key' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.last_enqueued_at(SomeIvarJob.to_s, t.to_s)

    assert_equal(0, Resque.enqueue_delayed_selection { |a| a.first == 'bar' })
    assert_equal(t.to_s, Resque.get_last_enqueued_at(SomeIvarJob.to_s))
  end

  test 'enqueue_delayed_selection enqueues item by class' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, Resque.enqueue_delayed_selection(SomeIvarJob) do |a|
      a.first == 'foo'
    end)
    assert_equal(1, Resque.count_all_scheduled_jobs)
  end

  test 'enqueue_delayed_selection enqueues item by class name as a string' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, Resque.enqueue_delayed_selection('SomeIvarJob') do |a|
      a.first == 'foo'
    end)
    assert_equal(1, Resque.count_all_scheduled_jobs)
  end

  test 'enqueue_delayed_selection enqueues item by class name as a symbol' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, Resque.enqueue_delayed_selection(:SomeIvarJob) do |a|
      a.first == 'foo'
    end)
    assert_equal(1, Resque.count_all_scheduled_jobs)
  end

  test 'enqueue_delayed_selection enqueues items only from' \
       'matching job class' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 1, SomeQuickJob, 'bar')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 2, SomeQuickJob, 'foo')

    assert_equal(2, Resque.enqueue_delayed_selection(SomeIvarJob) do |a|
      a.first == 'foo'
    end)
    assert_equal(4, Resque.count_all_scheduled_jobs)
  end

  test 'enqueue_delayed_selection enqueues items from matching job class ' \
       'without params' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t + 1, SomeQuickJob)
    Resque.enqueue_at(t + 2, SomeIvarJob)
    Resque.enqueue_at(t + 3, SomeQuickJob)

    assert_equal(2, Resque.enqueue_delayed_selection(SomeQuickJob) { true })
    assert_equal(2, Resque.count_all_scheduled_jobs)
  end

  test 'find_delayed_selection finds multiple items matching ' \
       'arguments at same timestamp' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'llama')
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'monkey')
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'platypus')
    Resque.enqueue_at(t, SomeIvarJob, 'baz')
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'llama')
    Resque.enqueue_at(t, SomeIvarJob, 'bar', 'llama')

    assert_equal(5, (Resque.find_delayed_selection do |a|
      a.first == 'bar'
    end).length)
  end

  test 'find_delayed_selection finds single item matching arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(1, (Resque.find_delayed_selection do |a|
      a.first == 'foo'
    end).length)
  end

  test 'find_delayed_selection finds multiple items matching arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(2, (Resque.find_delayed_selection do |a|
      a.first == 'bar'
    end).length)
  end

  test 'find_delayed_selection finds multiple items matching ' \
       'arguments as hash' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, foo: 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, foo: 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, foo: 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, foo: 'baz')

    len = Resque.find_delayed_selection { |a| a.first['foo'] == 'bar' }.length
    assert_equal(2, len)
  end

  test 'find_delayed_selection ignores jobs with no arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t + 1, SomeIvarJob)
    Resque.enqueue_at(t + 2, SomeIvarJob)
    Resque.enqueue_at(t + 3, SomeIvarJob)

    assert_equal(0, (Resque.find_delayed_selection do |a|
      a.first == 'bar'
    end).length)
  end

  test "find_delayed_selection doesn't find items it shouldn't" do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(0, (Resque.find_delayed_selection do |a|
      a.first == 'qux'
    end).length)
  end

  test 'find_delayed_selection finds item by class' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, (Resque.find_delayed_selection(SomeIvarJob) do |a|
      a.first == 'foo'
    end).length)
  end

  test 'find_delayed_selection finds item by class name as a string' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, (Resque.find_delayed_selection('SomeIvarJob') do |a|
      a.first == 'foo'
    end).length)
  end

  test 'find_delayed_selection finds item by class name as a symbol' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, (Resque.find_delayed_selection(:SomeIvarJob) do |a|
      a.first == 'foo'
    end).length)
  end

  test 'find_delayed_selection finds items only from' \
       'matching job class' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 1, SomeQuickJob, 'bar')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 2, SomeQuickJob, 'foo')

    assert_equal(2, (Resque.find_delayed_selection(SomeIvarJob) do |a|
      a.first == 'foo'
    end).length)
  end

  test 'find_delayed_selection finds items from matching job class ' \
       'without params' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t + 1, SomeQuickJob)
    Resque.enqueue_at(t + 2, SomeIvarJob)
    Resque.enqueue_at(t + 3, SomeQuickJob)

    assert_equal(
      2, (Resque.find_delayed_selection(SomeQuickJob) { true }).length
    )
  end

  test 'remove_delayed_job_from_timestamp removes instances of jobs ' \
       'at a given timestamp' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    assert_equal(
      1, Resque.remove_delayed_job_from_timestamp(t, SomeIvarJob, 'foo')
    )
    assert_equal 0, Resque.delayed_timestamp_size(t)
  end

  test "remove_delayed_job_from_timestamp doesn't remove items from " \
       'other timestamps' do
    t1 = Time.now + 120
    t2 = t1 + 1
    Resque.enqueue_at(t1, SomeIvarJob, 'foo')
    Resque.enqueue_at(t2, SomeIvarJob, 'foo')
    assert_equal(
      1, Resque.remove_delayed_job_from_timestamp(t2, SomeIvarJob, 'foo')
    )
    assert_equal 1, Resque.delayed_timestamp_size(t1)
    assert_equal 0, Resque.delayed_timestamp_size(t2)
  end

  test 'when Resque.inline = true, remove_delayed_job_from_timestamp' \
       "doesn't remove any jobs and returns 0" do
    begin
      Resque.inline = true

      timestamp = Time.now + 120
      Resque.enqueue_at(timestamp, SomeIvarJob, 'foo', 'bar')

      assert_equal(0, Resque.delayed_timestamp_size(timestamp))
    ensure
      Resque.inline = false
    end
  end

  test 'remove_delayed_job_from_timestamp removes nothing if there ' \
       'are no matches' do
    t = Time.now + 120
    assert_equal(
      0, Resque.remove_delayed_job_from_timestamp(t, SomeIvarJob, 'foo')
    )
  end

  test 'remove_delayed_job_from_timestamp only removes items that ' \
       'match args' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeIvarJob, 'bar')
    assert_equal(
      1, Resque.remove_delayed_job_from_timestamp(t, SomeIvarJob, 'foo')
    )
    assert_equal 1, Resque.delayed_timestamp_size(t)
  end

  test 'remove_delayed_job_from_timestamp returns the number of ' \
       'items removed' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    assert_equal(
      1, Resque.remove_delayed_job_from_timestamp(t, SomeIvarJob, 'foo')
    )
  end

  test 'remove_delayed_job_from_timestamp should cleanup the delayed ' \
       'timestamp list if not jobs are left' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    assert_equal(
      1, Resque.remove_delayed_job_from_timestamp(t, SomeIvarJob, 'foo')
    )
    assert_resque_key_exists?("delayed:#{t.to_i}")
    assert Resque.delayed_queue_peek(0, 100).empty?
  end

  test 'invalid job class' do
    assert_raises Resque::NoQueueError do
      Resque.enqueue_in(10, String)
    end
  end

  test 'invalid number of seconds' do
    assert_raises ArgumentError do
      Resque.enqueue_in(Time.now, SomeIvarJob)
    end

    assert_raises ArgumentError do
      Resque.enqueue_in_with_queue('test', Time.now, SomeIvarJob)
    end
  end

  test 'requeues a job in the queue originally specified regardless' \
       'of the queue attached to the class' do
    Resque.enqueue_in_with_queue('notivar', 1, SomeIvarJob)

    assert_equal(1, Resque.count_all_scheduled_jobs)
    assert_equal(1, Resque.enqueue_delayed_selection { true })
    assert_equal(0, Resque.count_all_scheduled_jobs)

    assert_equal(1, Resque.size('notivar'))
    assert_equal(0, Resque.size(Resque.queue_from_class(SomeIvarJob)))
  end

  test 'inlining jobs with Resque.inline config' do
    begin
      Resque.inline = true
      Resque::Job.expects(:create).once.with(:ivar, SomeIvarJob, 'foo', 'bar')

      timestamp = Time.now + 120
      Resque.enqueue_at(timestamp, SomeIvarJob, 'foo', 'bar')

      assert_equal 0, Resque.count_all_scheduled_jobs
      assert_resque_key_exists?("delayed:#{timestamp.to_i}")
    ensure
      Resque.inline = false
    end
  end

  test 'delayed?' do
    Resque.enqueue_at Time.now + 1, SomeIvarJob
    Resque.enqueue_at Time.now + 1, SomeIvarJob, id: 1

    assert Resque.delayed?(SomeIvarJob, id: 1)
    assert !Resque.delayed?(SomeIvarJob, id: 2)
    assert Resque.delayed?(SomeIvarJob)
    assert !Resque.delayed?(SomeJob)
  end
end
