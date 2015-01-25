require_relative '../../../test_helper'

module ResqueWeb
  module Plugins
    module ResqueScheduler
      class RequeueTest < ActionDispatch::IntegrationTest
        fixtures :all

        setup do
          Resque.schedule = Test::RESQUE_SCHEDULE
          Resque::Scheduler.load_schedule!
        end

        test 'job without params' do
          # Regular jobs without params should redirect to /overview
          job_name = 'job_without_params'
          Resque::Scheduler.stubs(:enqueue_from_config)
            .once.with(Resque.schedule[job_name])

          post Engine.app.url_helpers.requeue_path, 'job_name' => job_name
          follow_redirect!
          assert_equal 'http://www.example.com/resque_web/overview', request.url
          assert response.ok?
        end

        test 'job with params' do
          # If a job has params defined,
          # it should render the template with a form for the job params
          job_name = 'job_with_params'
          post Engine.app.url_helpers.requeue_path, 'job_name' => job_name

          assert response.ok?
          assert response.body.include?('This job requires parameters')
          assert response.body.include?(
                   %(<input type="hidden" name="job_name" value="#{job_name}">)
                 )

          Resque.schedule[job_name]['parameters'].each do |_param_name,
                                                           param_config|
            assert response.body.include?(
                       '<span style="border-bottom:1px dotted;" ' <<
                           %[title="#{param_config['description']}">(?)</span>]
                   )
            assert response.body.include?(
                       '<input type="text" name="log_level" ' <<
                           %(value="#{param_config['default']}">)
                   )
          end
        end
      end
    end
  end
end
