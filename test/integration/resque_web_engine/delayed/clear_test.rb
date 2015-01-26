require_relative '../../../test_helper'

module ResqueWeb
  module Plugins
    module ResqueScheduler
      class DelayedClearTest < ActionDispatch::IntegrationTest
        # 'on POST to /delayed/clear' do
        test 'redirects to delayed' do
          post Engine.app.url_helpers.clear_path
          assert response.status == 302
          assert response.header['Location'].include? '/delayed'
        end
      end
    end
  end
end
