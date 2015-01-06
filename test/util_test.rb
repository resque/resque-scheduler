# vim:fileencoding=utf-8

describe 'Util' do
  def util
    Resque::Scheduler::Util
  end

  it 'constantizing' do
    assert util.constantize('Resque::Scheduler') == Resque::Scheduler
  end
end
