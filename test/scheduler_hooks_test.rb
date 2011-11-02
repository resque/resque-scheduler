require File.dirname(__FILE__) + '/test_helper'

context "scheduling jobs with hooks" do
  class JobThatCannotBeScheduledWithoutArguments < Resque::Job
    @queue = :job_that_cannot_be_scheduled_without_arguments
    def self.perform(*x);end
    def self.before_schedule_return_nil_if_arguments_not_supplied(*args)
      counters[:before_schedule] += 1
      return false if args.empty?
    end

    def self.after_schedule_do_something(*args)
      counters[:after_schedule] += 1
    end

    class << self
      def counters
        @counters ||= Hash.new{|h,k| h[k]=0}
      end
      def clean
        counters.clear
        self
      end
    end
  end
  
  setup do
    Resque::Scheduler.dynamic = false
    Resque.redis.del(:schedules)
    Resque.redis.del(:schedules_changed)
    Resque::Scheduler.mute = true
    Resque::Scheduler.clear_schedule!
    Resque::Scheduler.send(:class_variable_set, :@@scheduled_jobs, {})
  end

  test "before_schedule hook that does not return false should not block" do
    enqueue_time = Time.now + 12
    Resque.enqueue_at(enqueue_time, JobThatCannotBeScheduledWithoutArguments.clean, :foo)
    assert_equal(1, Resque.delayed_timestamp_size(enqueue_time.to_i), "delayed queue should have one entry now")
    assert_equal(1, JobThatCannotBeScheduledWithoutArguments.counters[:before_schedule], 'before_schedule was not run')
    assert_equal(1, JobThatCannotBeScheduledWithoutArguments.counters[:after_schedule], 'after_schedule was not run')
  end

  test "before_schedule hook that returns false should block" do
    enqueue_time = Time.now + 60
    assert_equal(0, JobThatCannotBeScheduledWithoutArguments.clean.counters[:before_schedule], 'before_schedule should be zero')
    Resque.enqueue_at(enqueue_time, JobThatCannotBeScheduledWithoutArguments.clean)
    assert_equal(0, Resque.delayed_timestamp_size(enqueue_time.to_i), "job should not have been put in queue")
    assert_equal(1, JobThatCannotBeScheduledWithoutArguments.counters[:before_schedule], 'before_schedule was not run')
    assert_equal(0, JobThatCannotBeScheduledWithoutArguments.counters[:after_schedule], 'after_schedule was run')
  end
end
