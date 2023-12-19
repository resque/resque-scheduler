# vim:fileencoding=utf-8
require_relative 'test_helper'

context 'Configuration' do
  %w(VERBOSE QUIET DYNAMIC_SCHEDULE).each do |setting|
    method = setting.downcase.to_sym
    method = :dynamic if setting == 'DYNAMIC_SCHEDULE'

    test "enabling #{method} from environment" do
      configuration.environment = { setting => 'true' }

      assert configuration.send(method)
    end

    test "disabling #{method} from environment" do
      configuration.environment = { setting => 'false' }

      assert !configuration.send(method)
    end
  end

  test 'setting lock_timeout from environment' do
    configuration.environment = { 'LOCK_TIMEOUT' => '47' }

    assert_equal 47, configuration.lock_timeout
  end

  test 'env set from Rails.env' do
    Rails.expects(:env).returns('development')

    assert_equal 'development', configuration.env
  end

  test 'env set from environment' do
    configuration.environment = { 'RAILS_ENV' => 'development' }

    assert_equal 'development', configuration.env
  end

  private

  def configuration
    @configuration ||= Module.new do
      extend Resque::Scheduler::Configuration
    end
  end
end
