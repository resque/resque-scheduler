# frozen_string_literal: true

require_relative '../test_helper'
require 'benchmark'
require 'stackprof'

context 'Resque::Scheduler' do
  setup do
    Resque.redis.redis.flushall
  end

  test 'testing with TEST_WITH_MIGRATOR is actually doing something' do
    5_000.times { Resque.enqueue_in_with_queue(:default, 0, SomeJob) }
    StackProf.run(mode: :cpu, raw: true, out: 'stackprof.dump') do
      puts Benchmark.measure { Resque::Scheduler.handle_delayed_items }
    end
  end
end
