require File.dirname(__FILE__) + '/test_helper'

class Resque::SchedulerTest < Test::Unit::TestCase

  def setup
    Resque::Scheduler.clear_schedule!
  end

  def test_enqueue_from_config_puts_stuff_in_the_resque_queue
    Resque.stubs(:enqueue).once.returns(true).with(SomeIvarJob, '/tmp')
    Resque::Scheduler.enqueue_from_config('cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp")
  end

  def test_config_makes_it_into_the_rufus_scheduler
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)

    Resque.schedule = {:some_ivar_job => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp"}}
    Resque::Scheduler.load_schedule!

    assert_equal(1, Resque::Scheduler.rufus_scheduler.all_jobs.size)
  end

end