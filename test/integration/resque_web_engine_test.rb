require_relative '../test_helper'

class ResqueWebEngineTest < ActionDispatch::IntegrationTest
  fixtures :all

  # test "the truth" do
  #   assert true
  # end

  test 'the schedule tab should show up in Resque Web' do
    visit '/resque_web'
    click_link 'Schedule'
    assert_select 'title', 'Schedule'
  end
end