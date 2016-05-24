# vim:fileencoding=utf-8
require_relative 'test_helper'

context 'Multi Process' do
  test 'setting schedule= from many process does not corrupt the schedules' do
    # more info on why we're not using threads:
    # https://github.com/resque/resque-scheduler/pull/439#discussion_r16788812
    omit('forking is not supported by jruby but this behaviour' \
      ' is best tested using forks') if RUBY_ENGINE == 'jruby'
    schedules_1 = {}
    schedules_2 = {}
    schedules = []
    pids = []

    # This number may need to be increased if this test is not failing
    processes = 100

    schedule_count = 300

    schedule_count.times do |n|
      schedules_1["1_job_#{n}"] = { cron: '0 1 0 0 0' }
      schedules_2["2_job_#{n}"] = { cron: '0 1 0 0 0' }
    end

    processes.times do |n|
      pids << fork_with_marshalled_pipe_and_result do
        sleep n * 0.1
        Resque.schedule = n.even? ? schedules_2 : schedules_1
        Resque.schedule
      end
    end

    schedules += get_results_from_children(pids)

    assert_equal processes, schedules.size,
                 'missing some schedules, did a process die?'
    schedules.each_with_index do |schedule, i|
      assert_equal schedule_count, schedule.size,
                   "schedule count is incorrect (schedule[#{i}]: #{schedule})"
    end
  end

  test 'concurrent shutdowns and startups do not corrupt the schedule' do
    omit('forking is not supported by jruby but this behaviour' \
      ' is best tested using forks') if RUBY_ENGINE == 'jruby'
    counts = []
    children = []

    processes = 40

    schedules = {}
    schedule_count = 300
    schedule_count.times do |n|
      schedules["job_#{n}"] = { 'cron' => '0 1 0 0 0' }
    end

    Resque.schedule = schedules

    processes.times do |n|
      children << fork_with_marshalled_pipe_and_result do
        sleep Random.rand(3) * 0.1
        if n.even?
          Resque.schedule = schedules
          Resque.schedule.size
        else
          Resque::Scheduler.before_shutdown
          nil
        end
      end
    end

    counts += get_results_from_children(children).compact

    assert_equal processes / 2, counts.size,
                 'missing some counts, did a process die?'
    counts.each_with_index do |c, i|
      assert_equal schedule_count, c, "schedule count is incorrect (c: #{i})"
    end
  end

  private

  def fork_with_marshalled_pipe_and_result
    pipe_read, pipe_write = IO.pipe
    pid = fork do
      pipe_read.close
      result = begin
        [yield, nil]
      rescue StandardError => exc
        [nil, exc]
      end
      pipe_write.syswrite(Marshal.dump(result))
      # exit true the process to get around fork issues on minitest 5
      # see https://github.com/seattlerb/minitest/issues/467
      Process.exit!(true)
    end
    pipe_write.close

    [pid, pipe_read]
  end

  def get_results_from_children(children)
    results = []
    children.each do |pid, pipe|
      wait_for_child_process_to_terminate(pid)

      fail "forked process failed with #{$CHILD_STATUS}" unless $CHILD_STATUS.success?
      result, exc = Marshal.load(pipe.read)
      fail exc if exc
      results << result
    end
    results
  end

  def wait_for_child_process_to_terminate(pid = -1, timeout = 30)
    Timeout.timeout(timeout) do
      Process.wait(pid)
    end
  rescue Timeout::Error
    Process.kill('KILL', pid)
    # collect status so it doesn't stick around as zombie process
    Process.wait(pid)
    flunk 'Child process did not terminate in time.'
  end
end
