# vim:fileencoding=utf-8
require_relative 'test_helper'

context 'DelayedQueue' do
  setup do
    Resque::Scheduler.quiet = true
    Resque.redis.redis.flushall
  end

  test 'enqueue_at adds correct list and zset' do
    timestamp = Time.now + 1
    encoded_job = Resque.encode(
      class: SomeIvarJob.to_s,
      args: ['path'],
      queue: Resque.queue_from_class(SomeIvarJob)
    )

    assert_equal(0, Resque.redis.zcard(:delayed_queue).to_i,
                 'delayed queue should be empty to start')

    Resque.enqueue_at(timestamp, SomeIvarJob, 'path')

    # Confirm the correct keys were added
    assert_equal(1, Resque.redis.zcard(:delayed_queue),
                 'The delayed_queue should have 1 entry now')

    read_timestamp = timestamp.to_i

    item = Resque.next_delayed_items(before: read_timestamp)[0]

    # Confirm the item came out correctly
    assert_equal('SomeIvarJob', item['class'],
                 'Should be the same class that we queued')
    assert_equal(['path'], item['args'],
                 'Should have the same arguments that we queued')

    # And now confirm the keys are gone
    assert_equal(0, Resque.redis.zcard(:delayed_queue),
                 'delayed queue should be empty')
  end

  test 'enqueue_at with queue adds correct list and zset and queue' do
    timestamp = Time.now + 1
    encoded_job = Resque.encode(
      class: SomeIvarJob.to_s,
      args: ['path'],
      queue: 'critical'
    )

    assert_equal(0, Resque.redis.zcard(:delayed_queue).to_i,
                 'delayed queue should be empty to start')

    Resque.enqueue_at_with_queue('critical', timestamp, SomeIvarJob, 'path')

    # Confirm the correct keys were added

    read_timestamp = timestamp.to_i.to_f

    item = Resque.next_delayed_items(before: read_timestamp)[0]

    # Confirm the item came out correctly
    assert_equal('SomeIvarJob', item['class'],
                 'Should be the same class that we queued')
    assert_equal(['path'], item['args'],
                 'Should have the same arguments that we queued')
    assert_equal('critical', item['queue'],
                 'Should have the queue that we asked for')

    # And now confirm the keys are gone
    assert(!Resque.redis.exists("delayed:#{timestamp.to_i}"))
    assert_equal(0, Resque.redis.zcard(:delayed_queue_schedule),
                 'delayed queue should be empty')
  end

  test 'enqueue_at and enqueue_in are equivelent' do
    timestamp = Time.now + 60
    encoded_job = Resque.encode(
      class: SomeIvarJob.to_s,
      args: ['path'],
      queue: Resque.queue_from_class(SomeIvarJob)
    )

    Resque.enqueue_at(timestamp.to_i, SomeIvarJob, 'path')
    Resque.enqueue_in(timestamp.to_i - Time.now.to_i, SomeIvarJob, 'path')

    assert_equal(2, Resque.redis.zcard(:delayed_queue),
                 'should have 2 items in the queue')
  end

  test 'delayed_queue_schedule_size returns correct size' do
    assert_equal(0, Resque.delayed_queue_schedule_size)
    Resque.enqueue_at(Time.now + 60, SomeIvarJob)
    assert_equal(1, Resque.delayed_queue_schedule_size)
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

    batch_size = 10
    assert_equal batch_size, Resque::Scheduler.dequeue_batch_size

    (batch_size * 3).times { Resque.enqueue_at(t, SomeIvarJob) }

    # (batch_size * 3) SomeIvarJob jobs should be created in the "ivar" queue
    Resque::Job.expects(:create).times(batch_size * 3).with('ivar', SomeIvarJob, nil)
    Resque::Scheduler.handle_delayed_items(t)
  end

  test 'handle_delayed_items uses batch size of 10 by default' do
    assert_equal 10, Resque::Scheduler.dequeue_batch_size

    13.times { Resque.enqueue_in_with_queue('ivar', 0, SomeIvarJob) }

    # allow only one batch to get dequeued + enqueued
    Resque::Scheduler.stubs(:master?).returns(true).then.returns(false)

    Resque::Scheduler.handle_delayed_items

    assert_equal 3, Resque.delayed_queue_schedule_size
  end

  test 'calls klass#scheduled when enqueuing jobs if it exists' do
    t = Time.now - 60
    FakeCustomJobClassEnqueueAt.expects(:scheduled)
                               .once.with(:test, FakeCustomJobClassEnqueueAt.to_s, foo: 'bar')
    Resque.enqueue_at(t, FakeCustomJobClassEnqueueAt, foo: 'bar')
  end

  test 'when Resque.inline = true, calls klass#scheduled ' \
       'when enqueuing jobs if it exists' do
    old_val = Resque.inline
    begin
      Resque.inline = true
      t = Time.now - 60
      FakeCustomJobClassEnqueueAt.expects(:scheduled)
                                 .once.with(:test, FakeCustomJobClassEnqueueAt.to_s, foo: 'bar')
      Resque.enqueue_at(t, FakeCustomJobClassEnqueueAt, foo: 'bar')
    ensure
      Resque.inline = old_val
    end
  end

  test 'next_delayed_items picks count jobs if requested' do
    t = Time.now + 60

    6.times { Resque.enqueue_at(t, SomeIvarJob) }

    assert_equal 6, Resque.delayed_queue_schedule_size
    Resque.next_delayed_items(before: t, count: 4)
    assert_equal 2, Resque.delayed_queue_schedule_size
  end

  test 'next_delayed_items picks one job by default' do
    t = Time.now + 60

    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t, SomeIvarJob)

    assert_equal 2, Resque.delayed_queue_schedule_size
    Resque.next_delayed_items(before: t)
    assert_equal 1, Resque.delayed_queue_schedule_size
  end

  test 'handle_delayed_items works with out specifying queue ' \
       '(upgrade case)' do
    t = Time.now - 60
    Resque.send(:delayed_push, t, class: 'SomeIvarJob')

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
    assert_equal(2, Resque.delayed_queue_schedule_size)
  end

  test 'remove_delayed_selection removes single item matching arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(1, Resque.remove_delayed_selection { |a| a.first == 'foo' })
    assert_equal(3, Resque.delayed_queue_schedule_size)
  end

  test 'remove_delayed_selection removes multiple items matching arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(2, Resque.remove_delayed_selection { |a| a.first == 'bar' })
    assert_equal(2, Resque.delayed_queue_schedule_size)
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
    assert_equal(2, Resque.delayed_queue_schedule_size)
  end

  test 'remove_delayed_selection ignores jobs with no arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t + 1, SomeIvarJob)
    Resque.enqueue_at(t + 2, SomeIvarJob)
    Resque.enqueue_at(t + 3, SomeIvarJob)

    assert_equal(0, Resque.remove_delayed_selection { |a| a.first == 'bar' })
    assert_equal(4, Resque.delayed_queue_schedule_size)
  end

  test "remove_delayed_selection doesn't remove items it shouldn't" do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(0, Resque.remove_delayed_selection { |a| a.first == 'qux' })
    assert_equal(4, Resque.delayed_queue_schedule_size)
  end

  test 'remove_delayed_selection ignores last_enqueued_at redis key' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.last_enqueued_at(SomeIvarJob, t)

    assert_equal(0, Resque.remove_delayed_selection { |a| a.first == 'bar' })
    assert_equal(t.to_s, Resque.get_last_enqueued_at(SomeIvarJob))
  end

  test 'remove_delayed_selection removes item by class' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, Resque.remove_delayed_selection(SomeIvarJob) do |a|
      a.first == 'foo'
    end)
    assert_equal(1, Resque.delayed_queue_schedule_size)
  end

  test 'remove_delayed_selection removes item by class name as a string' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, Resque.remove_delayed_selection('SomeIvarJob') do |a|
      a.first == 'foo'
    end)
    assert_equal(1, Resque.delayed_queue_schedule_size)
  end

  test 'remove_delayed_selection removes item by class name as a symbol' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, Resque.remove_delayed_selection(:SomeIvarJob) do |a|
      a.first == 'foo'
    end)
    assert_equal(1, Resque.delayed_queue_schedule_size)
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
    assert_equal(4, Resque.delayed_queue_schedule_size)
  end

  test 'remove_delayed_selection removes items from matching job class ' \
       'without params' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t + 1, SomeQuickJob)
    Resque.enqueue_at(t + 2, SomeIvarJob)
    Resque.enqueue_at(t + 3, SomeQuickJob)

    assert_equal(2, Resque.remove_delayed_selection(SomeQuickJob) { true })
    assert_equal(2, Resque.delayed_queue_schedule_size)
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
    assert_equal(2, Resque.delayed_queue_schedule_size)
  end

  test 'enqueue_delayed_selection enqueues single item matching arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(1, Resque.enqueue_delayed_selection { |a| a.first == 'foo' })
    assert_equal(3, Resque.delayed_queue_schedule_size)
  end

  test 'enqueue_delayed_selection enqueues multiple items matching arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(2, Resque.enqueue_delayed_selection { |a| a.first == 'bar' })
    assert_equal(2, Resque.delayed_queue_schedule_size)
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
    assert_equal(2, Resque.delayed_queue_schedule_size)
  end

  test 'enqueue_delayed_selection ignores jobs with no arguments' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t + 1, SomeIvarJob)
    Resque.enqueue_at(t + 2, SomeIvarJob)
    Resque.enqueue_at(t + 3, SomeIvarJob)

    assert_equal(0, Resque.enqueue_delayed_selection { |a| a.first == 'bar' })
    assert_equal(4, Resque.delayed_queue_schedule_size)
  end

  test "enqueue_delayed_selection doesn't enqueue items it shouldn't" do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t + 1, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 2, SomeIvarJob, 'bar')
    Resque.enqueue_at(t + 3, SomeIvarJob, 'baz')

    assert_equal(0, Resque.enqueue_delayed_selection { |a| a.first == 'qux' })
    assert_equal(4, Resque.delayed_queue_schedule_size)
  end

  test 'enqueue_delayed_selection ignores last_enqueued_at redis key' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.last_enqueued_at(SomeIvarJob, t)

    assert_equal(0, Resque.enqueue_delayed_selection { |a| a.first == 'bar' })
    assert_equal(t.to_s, Resque.get_last_enqueued_at(SomeIvarJob))
  end

  test 'enqueue_delayed_selection enqueues item by class' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, Resque.enqueue_delayed_selection(SomeIvarJob) do |a|
      a.first == 'foo'
    end)
    assert_equal(1, Resque.delayed_queue_schedule_size)
  end

  test 'enqueue_delayed_selection enqueues item by class name as a string' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, Resque.enqueue_delayed_selection('SomeIvarJob') do |a|
      a.first == 'foo'
    end)
    assert_equal(1, Resque.delayed_queue_schedule_size)
  end

  test 'enqueue_delayed_selection enqueues item by class name as a symbol' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob, 'foo')
    Resque.enqueue_at(t, SomeQuickJob, 'foo')

    assert_equal(1, Resque.enqueue_delayed_selection(:SomeIvarJob) do |a|
      a.first == 'foo'
    end)
    assert_equal(1, Resque.delayed_queue_schedule_size)
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
    assert_equal(4, Resque.delayed_queue_schedule_size)
  end

  test 'enqueue_delayed_selection enqueues items from matching job class ' \
       'without params' do
    t = Time.now + 120
    Resque.enqueue_at(t, SomeIvarJob)
    Resque.enqueue_at(t + 1, SomeQuickJob)
    Resque.enqueue_at(t + 2, SomeIvarJob)
    Resque.enqueue_at(t + 3, SomeQuickJob)

    assert_equal(2, Resque.enqueue_delayed_selection(SomeQuickJob) { true })
    assert_equal(2, Resque.delayed_queue_schedule_size)
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

  test 'inlining jobs with Resque.inline config' do
    begin
      Resque.inline = true
      Resque::Job.expects(:create).once.with(:ivar, SomeIvarJob, 'foo', 'bar')

      timestamp = Time.now + 120
      Resque.enqueue_at(timestamp, SomeIvarJob, 'foo', 'bar')

      assert_equal 0, Resque.delayed_queue_schedule_size
      assert !Resque.redis.exists("delayed:#{timestamp.to_i}")
    ensure
      Resque.inline = false
    end
  end
end
