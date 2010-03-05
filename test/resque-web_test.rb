require File.dirname(__FILE__) + '/test_helper'
require '../resque/lib/resque/server/test_helper.rb'

context "on GET to /schedule" do
  setup { get "/schedule" }

  should_respond_with_success
end


context "on GET to /delayed" do
  setup { get "/delayed" }

  should_respond_with_success
end
