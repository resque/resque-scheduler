require File.dirname(__FILE__) + '/test_helper'

class Resque::SchedulerTest < Test::Unit::TestCase

  class FakeJob
    def self.scheduled(queue, klass, *args); end
  end

  def setup
    Resque.redis.del(:schedules)
    Resque::Scheduler.mute = true
    Resque::Scheduler.clear_schedule!
    Resque::Scheduler.send(:class_variable_set, :@@scheduled_jobs, {})
  end

  def test_enqueue_from_config_puts_stuff_in_the_resque_queue
    Resque::Job.stubs(:create).once.returns(true).with(:ivar, SomeIvarJob, '/tmp')
    Resque::Scheduler.enqueue_from_config('cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp")
  end
  
  def test_enqueue_from_config_with_custom_class_job_in_the_resque_queue
    FakeJob.stubs(:scheduled).once.returns(true).with(:ivar, 'SomeIvarJob', '/tmp')
    Resque::Scheduler.enqueue_from_config('cron' => "* * * * *", 'class' => 'SomeIvarJob', 'custom_job_class' => 'Resque::SchedulerTest::FakeJob', 'args' => "/tmp")
  end

  def test_enqueue_from_config_puts_stuff_in_the_resque_queue_when_env_match
    # The job should be loaded : its rails_env config matches the RAILS_ENV variable:
    ENV['RAILS_ENV'] = 'production'
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)

    Resque.schedule = {:some_ivar_job => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp", 'rails_env' => 'production'}}
    Resque::Scheduler.load_schedule!
    assert_equal(1, Resque::Scheduler.rufus_scheduler.all_jobs.size)

    # we allow multiple rails_env definition, it should work also:
    Resque.schedule = {:some_ivar_job => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp", 'rails_env' => 'staging, production'}}
    Resque::Scheduler.load_schedule!
    assert_equal(2, Resque::Scheduler.rufus_scheduler.all_jobs.size)
  end

  def test_enqueue_from_config_dont_puts_stuff_in_the_resque_queue_when_env_doesnt_match
    # RAILS_ENV is not set:
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)
    Resque.schedule = {:some_ivar_job => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp", 'rails_env' => 'staging'}}
    Resque::Scheduler.load_schedule!
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)

    # SET RAILS_ENV to a common value:
    ENV['RAILS_ENV'] = 'production'
    Resque.schedule = {:some_ivar_job => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp", 'rails_env' => 'staging'}}
    Resque::Scheduler.load_schedule!
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)
  end

  def test_enqueue_from_config_when_rails_env_arg_is_not_set
    # The job should be loaded, since a missing rails_env means ALL envs.
    ENV['RAILS_ENV'] = 'production'
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)
    Resque.schedule = {:some_ivar_job => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp"}}
    Resque::Scheduler.load_schedule!
    assert_equal(1, Resque::Scheduler.rufus_scheduler.all_jobs.size)
  end

  def test_config_makes_it_into_the_rufus_scheduler
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)

    Resque.schedule = {:some_ivar_job => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp"}}
    Resque::Scheduler.load_schedule!

    assert_equal(1, Resque::Scheduler.rufus_scheduler.all_jobs.size)
    assert Resque::Scheduler.scheduled_jobs.include?(:some_ivar_job)
  end
  
  def test_can_reload_schedule
    Resque.schedule = {"some_ivar_job" => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp"}}
    Resque.redis.hset(:schedules, "some_ivar_job", Resque.encode(
      {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp"}
    ))
  
    Resque::Scheduler.load_schedule!

    assert_equal(1, Resque::Scheduler.rufus_scheduler.all_jobs.size)
    assert Resque::Scheduler.scheduled_jobs.include?("some_ivar_job")
    
    Resque.redis.del(:schedules)
    Resque.redis.hset(:schedules, "some_ivar_job2", Resque.encode(
      {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp/2"}
    ))
    
    Resque::Scheduler.reload_schedule!
    
    assert_equal(1, Resque::Scheduler.rufus_scheduler.all_jobs.size)
    
    assert_equal '/tmp/2', Resque.schedule["some_ivar_job2"]["args"]
    assert Resque::Scheduler.scheduled_jobs.include?("some_ivar_job2")
  end
  
  def test_load_schedule_job
    Resque::Scheduler.load_schedule_job("some_ivar_job", {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp"})
    
    assert_equal(1, Resque::Scheduler.rufus_scheduler.all_jobs.size)
    assert_equal(1, Resque::Scheduler.scheduled_jobs.size)
    assert Resque::Scheduler.scheduled_jobs.keys.include?("some_ivar_job")
  end
  
  def test_load_schedule_job_with_no_cron
    Resque::Scheduler.load_schedule_job("some_ivar_job", {'class' => 'SomeIvarJob', 'args' => "/tmp"})
    
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)
    assert_equal(0, Resque::Scheduler.scheduled_jobs.size)
    assert !Resque::Scheduler.scheduled_jobs.keys.include?("some_ivar_job")
  end
  
  def test_load_schedule_job_with_blank_cron
    Resque::Scheduler.load_schedule_job("some_ivar_job", {'cron' => '', 'class' => 'SomeIvarJob', 'args' => "/tmp"})
    
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)
    assert_equal(0, Resque::Scheduler.scheduled_jobs.size)
    assert !Resque::Scheduler.scheduled_jobs.keys.include?("some_ivar_job")
  end
  
  def test_update_schedule
    Resque.schedule = {
      "some_ivar_job"    => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp"},
      "another_ivar_job" => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp/5"},
      "stay_put_job"     => {'cron' => "* * * * *", 'class' => 'SomeJob', 'args' => "/tmp"}
    }
    
    Resque::Scheduler.load_schedule!
    
    Resque.redis.hset(:schedules, "some_ivar_job", Resque.encode(
      {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp/2"}
    ))
    Resque.redis.hset(:schedules, "new_ivar_job", Resque.encode(
      {'cron' => "* * * * *", 'class' => 'SomeJob', 'args' => "/tmp/3"}
    ))
    Resque.redis.hset(:schedules, "stay_put_job", Resque.encode(
      {'cron' => "* * * * *", 'class' => 'SomeJob', 'args' => "/tmp"}
    ))
    
    Resque::Scheduler.update_schedule
    
    assert_equal(3, Resque::Scheduler.rufus_scheduler.all_jobs.size)
    assert_equal(3, Resque::Scheduler.scheduled_jobs.size)
    %w(some_ivar_job new_ivar_job stay_put_job).each do |job_name|
      assert Resque::Scheduler.scheduled_jobs.keys.include?(job_name)
      assert Resque.schedule.keys.include?(job_name)
    end
    assert !Resque::Scheduler.scheduled_jobs.keys.include?("another_ivar_job")
    assert !Resque.schedule.keys.include?("another_ivar_job")
  end
  
  def test_update_schedule_with_mocks
    Resque.schedule = {
      "some_ivar_job" => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp"},
      "another_ivar_job"  => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp/5"},
      "stay_put_job"  => {'cron' => "* * * * *", 'class' => 'SomeJob', 'args' => "/tmp"}
    }
    
    Resque::Scheduler.load_schedule!
    
    Resque::Scheduler.rufus_scheduler.expects(:unschedule).with(Resque::Scheduler.scheduled_jobs["some_ivar_job"].job_id)
    Resque::Scheduler.rufus_scheduler.expects(:unschedule).with(Resque::Scheduler.scheduled_jobs["another_ivar_job"].job_id)
    
    Resque.redis.hset(:schedules, "some_ivar_job", Resque.encode(
      {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp/2"}
    ))
    Resque.redis.hset(:schedules, "new_ivar_job", Resque.encode(
      {'cron' => "* * * * *", 'class' => 'SomeJob', 'args' => "/tmp/3"}
    ))
    Resque.redis.hset(:schedules, "stay_put_job", Resque.encode(
      {'cron' => "* * * * *", 'class' => 'SomeJob', 'args' => "/tmp"}
    ))
    
    Resque::Scheduler.update_schedule
    
    assert_equal(3, Resque::Scheduler.scheduled_jobs.size)
    %w(some_ivar_job new_ivar_job stay_put_job).each do |job_name|
      assert Resque::Scheduler.scheduled_jobs.keys.include?(job_name)
      assert Resque.schedule.keys.include?(job_name)
    end
    assert !Resque::Scheduler.scheduled_jobs.keys.include?("another_ivar_job")
    assert !Resque.schedule.keys.include?("another_ivar_job")
  end
  
  def test_set_schedule
    Resque.set_schedule("some_ivar_job", {
      'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp/22"
    })
    assert_equal({'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp/22"}, 
      Resque.decode(Resque.redis.hget(:schedules, "some_ivar_job")))
  end
  
  def test_get_schedule
    Resque.redis.hset(:schedules, "some_ivar_job2", Resque.encode(
      {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp/33"}
    ))
    assert_equal({'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp/33"}, 
      Resque.get_schedule("some_ivar_job2"))
  end
  
  def test_remove_schedule
    Resque.redis.hset(:schedules, "some_ivar_job3", Resque.encode(
      {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp/44"}
    ))
    Resque.remove_schedule("some_ivar_job3")
    assert_equal nil, Resque.redis.hget(:schedules, "some_ivar_job3")
  end

  def test_adheres_to_lint
    assert_nothing_raised do
      Resque::Plugin.lint(Resque::Scheduler)
    end
  end

end
