require_relative '../../../test_helper'

module ResqueWeb
  module Plugins
    module ResqueScheduler
      class TimestampTest < ActionDispatch::IntegrationTest
        test 'shows delayed_timestamp view' do
          get Engine.app.url_helpers.timestamp_path timestamp: '1234567890'
          assert response.status == 200
        end
      end
    end
  end
end
