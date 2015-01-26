require_relative '../../../test_helper'

module ResqueWeb
  module Plugins
    module ResqueScheduler
      class RequeueWithParamsTest < ActionDispatch::IntegrationTest
        setup do
          Resque.schedule = Test::RESQUE_SCHEDULE
          Resque::Scheduler.load_schedule!
        end

        test 'job with params' do
          job_name = 'job_with_params'
          log_level = 'error'

          job_config = Resque.schedule[job_name]
          args = job_config['args'].merge('log_level' => log_level)
          job_config = job_config.merge('args' => args)

          Resque::Scheduler.stubs(:enqueue_from_config).once.with(job_config)

          post Engine.app.url_helpers.requeue_with_params_path,
               'job_name' => job_name,
               'log_level' => log_level

          follow_redirect!
          assert_equal 'http://www.example.com/resque_web/overview', request.url

          assert response.ok?
        end
      end
    end
  end
end
