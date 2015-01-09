# Define a bare test case to use with Capybara
class ActionDispatch::IntegrationTest
  include Capybara::DSL
  include Rails.application.routes.url_helpers
end