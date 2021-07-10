# vim:fileencoding=utf-8

require 'resque/scheduler/job'

context 'Job' do
  test 'has nil default parameters' do
    class EmptyJob
      include Resque::Scheduler::Job
    end

    %i(cron every queue args description).each do |p|
      assert_nil EmptyJob.send(p)
    end
  end

  test 'saves values' do
    class JobWithValues
      include Resque::Scheduler::Job

      cron '* */3 * * *'
      every '3d'
      queue 'default'
      args 'some arg'
      description 'nice description'
    end

    assert_equal '* */3 * * *', JobWithValues.cron
    assert_equal '3d', JobWithValues.every
    assert_equal 'default', JobWithValues.queue
    assert_equal 'some arg', JobWithValues.args
    assert_equal 'nice description', JobWithValues.description
  end
end
