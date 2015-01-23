require_relative '../../../test_helper'

module ResqueWeb::Plugins::ResqueScheduler
  class DeleteDynamicScheduleTest < ActionDispatch::IntegrationTest
    setup do
      Resque.schedule = Test::RESQUE_SCHEDULE
      Resque::Scheduler.load_schedule!
      Resque::Scheduler.stubs(:dynamic).returns(true)
    end

    test 'redirects to schedule page' do
      delete Engine.app.url_helpers.schedule_path

      status = response.status
      redirect_location = response.headers['Location']
      response_status_msg = "Expected response to be a 302, but was a #{status}."
      redirect_msg = "Redirect to #{redirect_location} instead of /schedule."

      assert status == 302, response_status_msg
      assert_match %r{/schedule/?$}, redirect_location, redirect_msg
    end

    test 'does not show the deleted job' do
      delete Engine.app.url_helpers.schedule_path job_name: 'job_with_params'
      follow_redirect!

      msg = 'The job should not have been shown on the /schedule page.'
      assert !response.body.include?('job_with_params'), msg
    end

    test 'removes job from redis' do
      delete Engine.app.url_helpers.schedule_path, job_name: 'job_with_params'

      msg = 'The job was not deleted from redis.'
      assert_nil Resque.fetch_schedule('job_with_params'), msg
    end
  end
end