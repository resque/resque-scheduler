require File.dirname(__FILE__) + '/test_helper'

# Pull in the server test_helper from resque
require 'resque/server/test_helper.rb'

context "on GET to /schedule" do
  setup { get "/schedule" }

  should_respond_with_success
end

context "on GET to /schedule with scheduled jobs" do
  setup do
    ENV['rails_env'] = 'production'
    Resque.schedule = {'some_ivar_job' => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp", 'rails_env' => 'production'},
                       'some_other_job' => {'every' => ['5m'], 'queue' => 'high', 'class' => 'SomeOtherJob', 'args' => {'b' => 'blah'}}}
    Resque::Scheduler.load_schedule!
    get "/schedule"
  end

  should_respond_with_success

  test 'see the scheduled job' do
    assert last_response.body.include?('SomeIvarJob')
  end
end

context "on GET to /delayed" do
  setup { get "/delayed" }

  should_respond_with_success
end

def resque_schedule
  {
    'job_without_params' => {
      'cron' => "* * * * *",
      'class' => 'JobWithoutParams',
      'args' => {"host" => 'localhost'},
      'rails_env' => 'production'},
    'job_with_params' => {
      'cron' => "* * * * *",
      'class' => 'JobWithParams',
      'args' => {"host" => 'localhost'},
      'parameters' => {
        'log_level' => {
          'description' => 'The level of logging',
          'default' => 'warn'
        }
      }
    }
  }
end

context "POST /schedule/requeue" do
  setup do
    Resque.schedule = resque_schedule
    Resque::Scheduler.load_schedule!
  end

  test 'job without params' do
    # Regular jobs without params should redirect to /overview
    job_name = 'job_without_params'
    Resque::Scheduler.stubs(:enqueue_from_config).once.with(Resque.schedule[job_name])

    post '/schedule/requeue', {'job_name' => job_name}
    follow_redirect!
    assert_equal "http://example.org/overview", last_request.url
    assert last_response.ok?
  end

  test 'job with params' do
    # If a job has params defined,
    # it should render the template with a form for the job params
    job_name = 'job_with_params'
    post '/schedule/requeue', {'job_name' => job_name}

    assert last_response.ok?, last_response.errors
    assert last_response.body.include?("This job requires parameters")
    assert last_response.body.include?("<input type=\"hidden\" name=\"job_name\" value=\"#{job_name}\">")

    Resque.schedule[job_name]['parameters'].each do |param_name, param_config|
      assert last_response.body.include?(
        "<span style=\"border-bottom:1px dotted;\" title=\"#{param_config['description']}\">(?)</span>")
      assert last_response.body.include?(
        "<input type=\"text\" name=\"log_level\" value=\"#{param_config['default']}\">")
    end
  end
end

context "POST /schedule/requeue_with_params" do
  setup do
    Resque.schedule = resque_schedule
    Resque::Scheduler.load_schedule!
  end

  test 'job with params' do
    job_name = 'job_with_params'
    log_level = 'error'

    job_config = Resque.schedule[job_name]
    args = job_config['args'].merge({'log_level' => log_level})
    job_config = job_config.merge({'args' => args})

    Resque::Scheduler.stubs(:enqueue_from_config).once.with(job_config)

    post '/schedule/requeue_with_params', {
      'job_name' => job_name,
      'log_level' => log_level
    }
    follow_redirect!
    assert_equal "http://example.org/overview", last_request.url

    assert last_response.ok?, last_response.errors
  end
end
