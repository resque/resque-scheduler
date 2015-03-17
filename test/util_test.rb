# vim:fileencoding=utf-8

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
end
