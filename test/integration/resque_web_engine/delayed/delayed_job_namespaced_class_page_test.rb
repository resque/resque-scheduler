require_relative '../../../test_helper'
module ResqueWeb
  module Plugins
    module ResqueScheduler
      class DelayedJobNamespacedClassPageTest < ActionDispatch::IntegrationTest
        fixtures :all

        setup do
          @t = Time.now + 3600

          Resque.enqueue_at(@t, Foo::Bar, 'foo', 'bar')
          params = { klass: 'Foo::Bar', args: URI.encode(%w(foo bar).to_json) }
          visit Engine.app.url_helpers.delayed_job_class_path params
        end

        test('is 200') { assert page.status_code == 200 }

        test 'see the scheduled job' do
          assert page.body.include?(@t.to_s)
        end
      end
    end
  end
end
