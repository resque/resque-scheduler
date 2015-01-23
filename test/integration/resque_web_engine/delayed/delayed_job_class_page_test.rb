require_relative '../../../test_helper'

module ResqueWeb::Plugins::ResqueScheduler

  class DelayedJobClassPageTest < ActionDispatch::IntegrationTest
    fixtures :all

    setup do
      @t = Time.now + 3600
      Resque.enqueue_at(@t, SomeIvarJob, 'foo', 'bar')
      visit Engine.app.url_helpers.delayed_job_class_path klass: 'SomeIvarJob', args: URI.encode(%w(foo bar).to_json)
    end

    test('is 200') { assert page.status_code == 200 }

    test 'see the scheduled job' do
      assert page.body.include?(@t.to_s)
    end

  end
end