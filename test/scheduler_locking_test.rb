require File.dirname(__FILE__) + '/test_helper'

module LockTestHelper
  def lock_is_not_held(lock)
    Resque.redis.set(lock.key, 'anothermachine:1234')
  end
end

context 'Resque::SchedulerLocking' do
  setup do
    @subject = Class.new { extend Resque::SchedulerLocking }
  end

  teardown do
    Resque.redis.del(@subject.master_lock.key)
  end

  test 'it should use the basic lock mechanism for <= Redis 2.4' do
    Resque.redis.stubs(:info).returns('redis_version' => '2.4.16')

    assert_equal @subject.master_lock.class, Resque::Scheduler::Lock::Basic
  end

  test 'it should use the resilient lock mechanism for > Redis 2.4' do
    Resque.redis.stubs(:info).returns('redis_version' => '2.5.12')

    assert_equal @subject.master_lock.class, Resque::Scheduler::Lock::Resilient
  end

  test 'it should be the master if the lock is held' do
    @subject.master_lock.acquire!
    assert @subject.is_master?, 'should be master'
  end

  test 'it should not be the master if the lock is held by someone else' do
    Resque.redis.set(@subject.master_lock.key, 'somethingelse:1234')
    assert !@subject.is_master?, 'should not be master'
  end

  test "release_master_lock should delegate to master_lock" do
    @subject.master_lock.expects(:release!)
    @subject.release_master_lock!
  end
end

context 'Resque::Scheduler::Lock::Base' do
  setup do
    @lock = Resque::Scheduler::Lock::Base.new('test_lock_key')
  end

  test '#acquire! should be not implemented' do
    assert_raise(NotImplementedError) do
      @lock.acquire!
    end
  end

  test '#locked? should be not implemented' do
    assert_raise(NotImplementedError) do
      @lock.locked?
    end
  end
end

context 'Resque::Scheduler::Lock::Basic' do
  include LockTestHelper

  setup do
    @lock = Resque::Scheduler::Lock::Basic.new('test_lock_key')
  end

  teardown do
    @lock.release!
  end

  test 'you should not have the lock if someone else holds it' do
    lock_is_not_held(@lock)

    assert !@lock.locked?
  end

  test 'you should not be able to acquire the lock if someone else holds it' do
    lock_is_not_held(@lock)

    assert !@lock.acquire!
  end

  test "the lock should receive a TTL on acquiring" do
    @lock.acquire!

    assert Resque.redis.ttl(@lock.key) > 0, "lock should expire"
  end

  test 'releasing should release the master lock' do
    assert @lock.acquire!, 'should have acquired the master lock'
    assert @lock.locked?, 'should be locked'

    @lock.release!

    assert !@lock.locked?, 'should not be locked'
  end

  test 'checking the lock should increase the TTL if we hold it' do
    @lock.acquire!
    Resque.redis.setex(@lock.key, 10, @lock.value)

    @lock.locked?

    assert Resque.redis.ttl(@lock.key) > 10, "TTL should have been updated"
  end

  test 'checking the lock should not increase the TTL if we do not hold it' do
    Resque.redis.setex(@lock.key, 10, @lock.value)
    lock_is_not_held(@lock)

    @lock.locked?

    assert Resque.redis.ttl(@lock.key) <= 10, "TTL should not have been updated"
  end
end

context 'Resque::Scheduler::Lock::Resilient' do
  include LockTestHelper

  if !Resque::Scheduler.supports_lua?
    puts "*** Skipping Resque::Scheduler::Lock::Resilient tests, as they require Redis >= 2.5."
  else
    setup do
      @lock = Resque::Scheduler::Lock::Resilient.new('test_resilient_lock')
    end

    teardown do
      @lock.release!
    end

    test 'you should not have the lock if someone else holds it' do
      lock_is_not_held(@lock)

      assert !@lock.locked?, 'you should not have the lock'
    end

    test 'you should not be able to acquire the lock if someone else holds it' do
      lock_is_not_held(@lock)

      assert !@lock.acquire!
    end

    test "the lock should receive a TTL on acquiring" do
      @lock.acquire!

      assert Resque.redis.ttl(@lock.key) > 0, "lock should expire"
    end

    test 'releasing should release the master lock' do
      assert @lock.acquire!, 'should have acquired the master lock'
      assert @lock.locked?, 'should be locked'

      @lock.release!

      assert !@lock.locked?, 'should not be locked'
    end

    test 'checking the lock should increase the TTL if we hold it' do
      @lock.acquire!
      Resque.redis.setex(@lock.key, 10, @lock.value)

      @lock.locked?

      assert Resque.redis.ttl(@lock.key) > 10, "TTL should have been updated"
    end

    test 'checking the lock should not increase the TTL if we do not hold it' do
      Resque.redis.setex(@lock.key, 10, @lock.value)
      lock_is_not_held(@lock)

      @lock.locked?

      assert Resque.redis.ttl(@lock.key) <= 10, "TTL should not have been updated"
    end
  end
end
