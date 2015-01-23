require_relative '../../../test_helper'

module ResqueWeb::Plugins::ResqueScheduler
  class CancelNowTest < ActionDispatch::IntegrationTest

    test 'redirects to overview' do
      post Engine.app.url_helpers.cancel_now_path
      assert response.status == 302
      assert response.header['Location'].include? '/delayed'
    end
  end
end