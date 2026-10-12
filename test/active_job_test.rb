require_relative 'test_helper'
require 'active_job'
require 'active_job/queue_adapters/resque_adapter'

ActiveJob::Base.logger = Logger.new(nil)

class SomeActiveJob < ActiveJob::Base
  self.queue_adapter = :resque
  queue_as :active

  def perform(*_args); end
end

context 'Active Job' do
  setup do
    Resque::Scheduler.quiet = true
    Resque.data_store.redis.flushall
  end

  test 'enqueue_at delays a job that performs through Active Job' do
    timestamp = Time.now + 60
    Resque.enqueue_at(timestamp, SomeActiveJob, 'path')

    Resque::Scheduler.enqueue_delayed_items_for_timestamp(timestamp.to_i)
    SomeActiveJob.any_instance.expects(:perform).with('path')
    Resque.reserve('active').perform
  end

  test 'enqueue_at_with_queue overrides queue_as' do
    timestamp = Time.now + 60
    Resque.enqueue_at_with_queue('other', timestamp, SomeActiveJob)

    assert_equal 'other',
                 Resque.next_item_for_timestamp(timestamp.to_i)['queue']
  end

  test 'enqueue_from_config uses queue_as unless a queue is configured' do
    Resque::Scheduler.enqueue_from_config(
      'class' => 'SomeActiveJob', 'args' => 'path'
    )
    Resque::Scheduler.enqueue_from_config(
      'class' => 'SomeActiveJob', 'queue' => 'other'
    )

    assert_equal 1, Resque.size('other')
    SomeActiveJob.any_instance.expects(:perform).with('path')
    Resque.reserve('active').perform
  end
end
