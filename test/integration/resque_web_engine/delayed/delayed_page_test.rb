require_relative '../../../test_helper'

module ResqueWeb
  module Plugins
    module ResqueScheduler
      class DelayedTest < ActionDispatch::IntegrationTest
        test 'Link to delayed page in navigation works' do
          visit '/resque_web'
          click_link 'Delayed'
          assert page.status_code == 200
          assert page.has_css? 'h1', 'Delayed Jobs'
        end
      end
    end
  end
end
