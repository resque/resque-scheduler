# vim:fileencoding=utf-8

context 'Util' do
  def util
    ResqueScheduler::Util
  end

  test 'constantizing' do
    assert util.constantize('resque-scheduler') == ResqueScheduler
  end
end
