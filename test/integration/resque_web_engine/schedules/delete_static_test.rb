require_relative '../../../test_helper'

module ResqueWeb::Plugins::ResqueScheduler
  class DelayedSearchTest < ActionDispatch::IntegrationTest
    setup do
      Resque.schedule = Test::RESQUE_SCHEDULE
      Resque::Scheduler.load_schedule!
      Resque::Scheduler.stubs(:dynamic).returns(false)
    end

    test 'does not remove the job from the UI' do
      delete Engine.app.url_helpers.schedule_path, job_name: 'job_with_params'
      follow_redirect!

      msg = 'The job should not have been removed from the /schedule page.'
      assert response.body.include?('job_with_params'), msg
    end

    test 'does not remove job from redis' do
      delete Engine.app.url_helpers.schedule_path, job_name: 'job_with_params'

      msg = 'The job should not have been deleted from redis.'
      assert Resque.fetch_schedule('job_with_params'), msg
    end
  end
end