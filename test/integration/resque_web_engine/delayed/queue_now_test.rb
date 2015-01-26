require_relative '../../../test_helper'

module ResqueWeb
  module Plugins
    module ResqueScheduler
      class QueueNowTest < ActionDispatch::IntegrationTest
        # 'on POST to /delayed/queue_now' do
        test 'redirects to overview' do
          post Engine.app.url_helpers.queue_now_path
          assert response.status == 302
          assert response.header['Location'].include? '/overview'
        end
      end
    end
  end
end
