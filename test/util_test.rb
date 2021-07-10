# vim:fileencoding=utf-8
require_relative 'test_helper'

context 'Util' do
  def util
    Resque::Scheduler::Util
  end

  test 'constantizing' do
    assert util.constantize('Resque::Scheduler') == Resque::Scheduler
  end

  module ReSchedulIzer; end

  test 'constantizing with a dash' do
    assert util.constantize('re-schedul-izer') == ReSchedulIzer
  end

  test 'constantizing with an underscore' do
    assert util.constantize('re_schedul_izer') == ReSchedulIzer
  end
end
