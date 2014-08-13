# vim:fileencoding=utf-8
require_relative 'test_helper'

context 'Multi Process' do
  test 'setting schedule= from many process does not corrupt the schedules' do
    schedules = {}
    counts  = []
    threads = []

    # This number may need to be increased if this test is not failing
    processes = 20

    schedule_count = 200

    schedule_count.times do |n|
      schedules["job #{n}"] = { cron: '0 1 0 0 0' }
    end

    processes.times do |n|
      threads << Thread.new do
        sleep n * 0.1
        Resque.schedule = schedules
        counts << Resque.schedule.size
      end
    end

    # doing this outside the threads increases the odds of failure
    Resque.schedule = schedules
    counts << Resque.schedule.size

    threads.each { |t| t.join }

    counts.each_with_index do |c, i|
      assert_equal schedule_count, c, "schedule count is incorrect (c: #{i})"
    end
  end

  # This explains what is happening above.
  # One process is calling clean_schedules while another is setting its
  # schedules up.
  test 'set_schedules and clean_schedules do not conflict' do
    schedules = {}
    threads = []

    schedule_count = 20

    schedule_count.times do |n|
      schedules["job #{n}"] = { cron: '0 1 0 0 0' }
    end

    threads << Thread.new do
      schedules.each do |name, conf|
        Resque.set_schedule(name, conf)
        sleep 0.1
      end
    end

    threads << Thread.new do
      sleep 0.5
      Resque.clean_schedules
    end

    threads.each { |t| t.join }

    Resque.reload_schedule!
    assert_equal schedule_count, Resque.schedule.size
  end
end
