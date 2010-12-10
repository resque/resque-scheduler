require File.dirname(__FILE__) + '/test_helper'

context "scheduling jobs with arguments" do
  setup { Resque::Scheduler.clear_schedule! }

  test "calls the worker without arguments when 'args' is missing from the config" do
    Resque::Scheduler.enqueue_from_config(YAML.load(<<-YAML))
      class: SomeIvarJob
    YAML
    SomeIvarJob.expects(:perform).once.with()
    Resque.reserve('ivar').perform
  end

  test "calls the worker without arguments when 'args' is blank in the config" do
    Resque::Scheduler.enqueue_from_config(YAML.load(<<-YAML))
      class: SomeIvarJob
      args: 
    YAML
    SomeIvarJob.expects(:perform).once.with()
    Resque.reserve('ivar').perform
  end

  test "calls the worker with a string when the config lists a string" do
    Resque::Scheduler.enqueue_from_config(YAML.load(<<-YAML))
      class: SomeIvarJob
      args: string
    YAML
    SomeIvarJob.expects(:perform).once.with('string')
    Resque.reserve('ivar').perform
  end

  test "calls the worker with a Fixnum when the config lists an integer" do
    Resque::Scheduler.enqueue_from_config(YAML.load(<<-YAML))
      class: SomeIvarJob
      args: 1
    YAML
    SomeIvarJob.expects(:perform).once.with(1)
    Resque.reserve('ivar').perform
  end

  test "calls the worker with multiple arguments when the config lists an array" do
    Resque::Scheduler.enqueue_from_config(YAML.load(<<-YAML))
      class: SomeIvarJob
      args:
        - 1
        - 2
    YAML
    SomeIvarJob.expects(:perform).once.with(1, 2)
    Resque.reserve('ivar').perform
  end

  test "calls the worker with an array when the config lists a nested array" do
    Resque::Scheduler.enqueue_from_config(YAML.load(<<-YAML))
      class: SomeIvarJob
      args:
        - - 1
          - 2
    YAML
    SomeIvarJob.expects(:perform).once.with([1, 2])
    Resque.reserve('ivar').perform
  end

  test "calls the worker with a hash when the config lists a hash" do
    Resque::Scheduler.enqueue_from_config(YAML.load(<<-YAML))
      class: SomeIvarJob
      args:
        key: value
    YAML
    SomeIvarJob.expects(:perform).once.with('key' => 'value')
    Resque.reserve('ivar').perform
  end

  test "calls the worker with a nested hash when the config lists a nested hash" do
    Resque::Scheduler.enqueue_from_config(YAML.load(<<-YAML))
      class: SomeIvarJob
      args:
        first_key:
          second_key: value
    YAML
    SomeIvarJob.expects(:perform).once.with('first_key' => {'second_key' => 'value'})
    Resque.reserve('ivar').perform
  end
end
