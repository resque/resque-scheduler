# Define a bare test case to use with Capybara
module ActionDispatch
  class IntegrationTest
    include Capybara::DSL
    include Rails.application.routes.url_helpers
  end
end
