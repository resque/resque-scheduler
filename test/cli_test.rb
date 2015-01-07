# vim:fileencoding=utf-8
require_relative 'test_helper'

describe 'Cli' do

  before { reset_resque_scheduler }

  def mock_runtime_env
    mock.tap { |m| m.stubs(:setup) }
  end

  def new_cli(argv = [], env = {})
    Resque::Scheduler::Cli.new(argv, env).tap do |cli|
      cli.stubs(:runtime_env).returns(mock_runtime_env)
    end
  end

  it 'does not require any positional arguments' do
    assert(!new_cli.nil?)
  end

  it 'initializes verbose from the env' do
    cli = new_cli([], 'VERBOSE' => 'foo')
    assert_equal('foo', cli.send(:options)[:verbose])
  end

  it 'defaults to non-verbose' do
    assert_equal(false, !!new_cli.send(:options)[:verbose])
  end

  it 'accepts verbose via -v' do
    cli = new_cli(%w(-v))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:verbose])
  end

  it 'accepts verbose via --verbose' do
    cli = new_cli(%w(--verbose))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:verbose])
  end

  it 'initializes background from the env' do
    cli = new_cli([], 'BACKGROUND' => '1')
    assert_equal('1', cli.send(:options)[:background])
  end

  it 'defaults to background=false' do
    assert_equal(false, !!new_cli.send(:options)[:background])
  end

  it 'accepts background via -B' do
    cli = new_cli(%w(-B))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:background])
  end

  it 'accepts background via --background' do
    cli = new_cli(%w(--background))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:background])
  end

  it 'initializes pidfile from the env' do
    cli = new_cli([], 'PIDFILE' => 'bar')
    assert_equal('bar', cli.send(:options)[:pidfile])
  end

  it 'defaults to nil pidfile' do
    assert_equal(nil, new_cli.send(:options)[:pidfile])
  end

  it 'accepts pidfile via -P' do
    cli = new_cli(%w(-P foo))
    cli.parse_options
    assert_equal('foo', cli.send(:options)[:pidfile])
  end

  it 'accepts pidfile via --pidfile' do
    cli = new_cli(%w(--pidfile foo))
    cli.parse_options
    assert_equal('foo', cli.send(:options)[:pidfile])
  end

  it 'defaults to nil dynamic' do
    assert_equal(nil, new_cli.send(:options)[:dynamic])
  end

  it 'initializes env from the env' do
    cli = new_cli([], 'RAILS_ENV' => 'flurb')
    assert_equal('flurb', cli.send(:options)[:env])
  end

  it 'defaults to nil env' do
    assert_equal(nil, new_cli.send(:options)[:env])
  end

  it 'accepts env via -E' do
    cli = new_cli(%w(-E bork))
    cli.parse_options
    assert_equal('bork', cli.send(:options)[:env])
  end

  it 'accepts env via --environment' do
    cli = new_cli(%w(--environment hork))
    cli.parse_options
    assert_equal('hork', cli.send(:options)[:env])
  end

  it 'initializes initializer_path from the env' do
    cli = new_cli([], 'INITIALIZER_PATH' => 'herp.rb')
    assert_equal('herp.rb', cli.send(:options)[:initializer_path])
  end

  it 'defaults to nil initializer_path' do
    assert_equal(nil, new_cli.send(:options)[:initializer_path])
  end

  it 'accepts initializer_path via -I' do
    cli = new_cli(%w(-I hambone.rb))
    cli.parse_options
    assert_equal('hambone.rb', cli.send(:options)[:initializer_path])
  end

  it 'accepts initializer_path via --initalizer-path' do
    cli = new_cli(%w(--initializer-path cookies.rb))
    cli.parse_options
    assert_equal('cookies.rb', cli.send(:options)[:initializer_path])
  end

  it 'loads given initilalizer_path' do
    cli = new_cli(%w(--initializer-path fuzzbert.rb))
    cli.expects(:load).with('fuzzbert.rb')
    cli.pre_run
  end

  it 'initializes quiet from the env' do
    cli = new_cli([], 'QUIET' => '1')
    assert_equal('1', cli.send(:options)[:quiet])
  end

  it 'defaults to un-quieted' do
    assert_equal(false, !!new_cli.send(:options)[:quiet])
  end

  it 'accepts quiet via -q' do
    cli = new_cli(%w(-q))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:quiet])
  end

  it 'accepts quiet via --quiet' do
    cli = new_cli(%w(--quiet))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:quiet])
  end

  it 'initializes logfile from the env' do
    cli = new_cli([], 'LOGFILE' => 'example.log')
    assert_equal('example.log', cli.send(:options)[:logfile])
  end

  it 'defaults to nil logfile' do
    assert_equal(nil, new_cli.send(:options)[:logfile])
  end

  it 'accepts logfile via -l' do
    cli = new_cli(%w(-l hurm.out))
    cli.parse_options
    assert_equal('hurm.out', cli.send(:options)[:logfile])
  end

  it 'accepts logfile via --logfile' do
    cli = new_cli(%w(--logfile flam.log))
    cli.parse_options
    assert_equal('flam.log', cli.send(:options)[:logfile])
  end

  it 'initializes logformat from the env' do
    cli = new_cli([], 'LOGFORMAT' => 'fancy')
    assert_equal('fancy', cli.send(:options)[:logformat])
  end

  it 'defaults to nil logformat' do
    assert_equal(nil, new_cli.send(:options)[:logformat])
  end

  it 'accepts logformat via -F' do
    cli = new_cli(%w(-F silly))
    cli.parse_options
    assert_equal('silly', cli.send(:options)[:logformat])
  end

  it 'accepts logformat via --logformat' do
    cli = new_cli(%w(--logformat flimsy))
    cli.parse_options
    assert_equal('flimsy', cli.send(:options)[:logformat])
  end

  it 'defaults to dynamic=false' do
    assert_equal(false, !!new_cli.send(:options)[:dynamic])
  end

  it 'initializes app_name from the env' do
    cli = new_cli([], 'APP_NAME' => 'sprocket')
    assert_equal('sprocket', cli.send(:options)[:app_name])
  end

  it 'defaults to nil app_name' do
    assert_equal(nil, new_cli.send(:options)[:app_name])
  end

  it 'accepts app_name via -n' do
    cli = new_cli(%w(-n hambone))
    cli.parse_options
    assert_equal('hambone', cli.send(:options)[:app_name])
  end

  it 'accepts app_name via --app-name' do
    cli = new_cli(%w(--app-name flimsy))
    cli.parse_options
    assert_equal('flimsy', cli.send(:options)[:app_name])
  end

  it 'runs Resque::Scheduler' do
    Resque::Scheduler.expects(:run)
    Resque::Scheduler::Cli.run!([], {})
  end
end
