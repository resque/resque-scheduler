# frozen_string_literal: true

require_relative '../test_helper'
require 'benchmark'

context 'Resque::Scheduler' do
  setup do
    Resque.redis.redis.flushall
  end

  test "benchmark dequeuing" do
    [1, 10].each do |batch_size|
      10_000.times { Resque.enqueue_in_with_queue(:default, 0, SomeJob) }

      with_dequeue_batch_size(batch_size) do
        puts "benchmarking dequeuing in batches of #{batch_size}"
        puts Benchmark.measure { Resque::Scheduler.handle_delayed_items }
      end
    end
  end

  private

  def with_dequeue_batch_size(batch_size)
    old = Resque::Scheduler.dequeue_batch_size
    Resque::Scheduler.dequeue_batch_size = batch_size
    yield
  ensure
    Resque::Scheduler.dequeue_batch_size = old
  end
end
