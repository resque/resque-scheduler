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
    Resque.schedule = {:some_ivar_job => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp", 'rails_env' => 'production'},
                       :some_other_job => {'queue' => 'high', 'class' => 'SomeOtherJob', 'args' => {:b => 'blah'}}}
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
