# vim:fileencoding=utf-8
require_relative 'test_helper'

describe 'Util' do
  def util
    Resque::Scheduler::Util
  end

  before { reset_resque_scheduler }

  it 'constantizing' do
    assert util.constantize('Resque::Scheduler') == Resque::Scheduler
  end
end
