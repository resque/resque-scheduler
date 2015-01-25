require_relative '../../../test_helper'

module ResqueWeb
  module Plugins
    module ResqueScheduler
      class ScheduleTest < ActionDispatch::IntegrationTest
        fixtures :all

        def visit_scheduler_page
          visit Engine.app.url_helpers.schedules_path
        end

        setup do
          Resque::Scheduler.env = 'production'
          Resque.schedule = {
            'some_ivar_job' => {
              'cron' => '* * * * *',
              'class' => 'SomeIvarJob',
              'args' => '/tmp',
              'rails_env' => 'production'
            },
            'some_other_job' => {
              'every' => ['1m', ['1h']],
              'queue' => 'high',
              'custom_job_class' => 'SomeOtherJob',
              'args' => {
                'b' => 'blah'
              }
            },
            'some_fancy_job' => {
              'every' => ['1m'],
              'queue' => 'fancy',
              'class' => 'SomeFancyJob',
              'args' => 'sparkles',
              'rails_env' => 'fancy'
            },
            'shared_env_job' => {
              'cron' => '* * * * *',
              'class' => 'SomeSharedEnvJob',
              'args' => '/tmp',
              'rails_env' => 'fancy, production'
            }
          }
          Resque::Scheduler.load_schedule!
          visit_scheduler_page
        end

        test 'Link to Schedule page in navigation works' do
          visit '/resque_web'
          click_link 'Schedule'
          assert page.has_css? 'h1', 'Schedule'
        end

        test '200' do
          assert page.has_css?('h1', 'Schedule')
        end

        test 'see the scheduled job' do
          assert page.body.include?('SomeIvarJob')
        end

        test 'excludes jobs for other envs' do
          assert !page.body.include?('SomeFancyJob')
        end

        test 'includes job used in multiple environments' do
          assert page.body.include?('SomeSharedEnvJob')
        end

        test 'allows delete when dynamic' do
          Resque::Scheduler.stubs(:dynamic).returns(true)
          visit_scheduler_page

          assert page.body.include?('Delete')
        end

        test "doesn't allow delete when static" do
          Resque::Scheduler.stubs(:dynamic).returns(false)
          visit_scheduler_page

          assert !page.body.include?('Delete')
        end
      end
    end
  end
end
