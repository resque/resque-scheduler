require_relative 'test_helper'

context 'Cli' do
  def new_cli(argv = [], env = {})
    ResqueScheduler::Cli.new(argv, env)
  end

  test 'does not require any positional arguments' do
    assert(!new_cli.nil?)
  end

  test 'initializes verbose from the env' do
    cli = new_cli([], { 'VERBOSE' => 'foo' })
    assert_equal('foo', cli.send(:options)[:verbose])
  end

  test 'defaults to non-verbose' do
    assert_equal(false, !!new_cli.send(:options)[:verbose])
  end

  test 'accepts verbose via -v' do
    cli = new_cli(%w(-v))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:verbose])
  end

  test 'accepts verbose via --verbose' do
    cli = new_cli(%w(--verbose))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:verbose])
  end

  test 'initializes background from the env' do
    cli = new_cli([], { 'BACKGROUND' => '1' })
    assert_equal('1', cli.send(:options)[:background])
  end

  test 'defaults to background=false' do
    assert_equal(false, !!new_cli.send(:options)[:background])
  end

  test 'accepts background via -B' do
    cli = new_cli(%w(-B))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:background])
  end

  test 'accepts background via --background' do
    cli = new_cli(%w(--background))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:background])
  end

  test 'daemonizes when background is true' do
    Process.expects(:daemon)
    cli = new_cli(%w(--background))
    cli.pre_run
  end

  test 'reconnects redis when background is true' do
    Process.stubs(:daemon)
    mock_redis_client = mock('redis_client')
    mock_redis = mock('redis')
    mock_redis.expects(:client).returns(mock_redis_client)
    mock_redis_client.expects(:reconnect)
    Resque.expects(:redis).returns(mock_redis)
    cli = new_cli(%w(--background))
    cli.pre_run
  end

  test 'aborts when background is given and Process does not support daemon' do
    Process.stubs(:daemon)
    Process.expects(:respond_to?).with('daemon').returns(false)
    cli = new_cli(%w(--background))
    cli.expects(:abort)
    cli.pre_run
  end

  test 'initializes pidfile from the env' do
    cli = new_cli([], { 'PIDFILE' => 'bar' })
    assert_equal('bar', cli.send(:options)[:pidfile])
  end

  test 'defaults to nil pidfile' do
    assert_equal(nil, new_cli.send(:options)[:pidfile])
  end

  test 'accepts pidfile via -P' do
    cli = new_cli(%w(-P foo))
    cli.parse_options
    assert_equal('foo', cli.send(:options)[:pidfile])
  end

  test 'accepts pidfile via --pidfile' do
    cli = new_cli(%w(--pidfile foo))
    cli.parse_options
    assert_equal('foo', cli.send(:options)[:pidfile])
  end

  test 'writes pid to pidfile when given' do
    mock_pidfile = mock('pidfile')
    mock_pidfile.expects(:puts)
    File.expects(:open).with('derp.pid', 'w').yields(mock_pidfile)
    cli = new_cli(%w(--pidfile derp.pid))
    cli.pre_run
  end

  test 'initializes dynamic from the env' do
    cli = new_cli([], { 'DYNAMIC_SCHEDULE' => '1' })
    assert_equal('flurb', cli.send(:options)[:dynamic])
  end

  test 'defaults to nil dynamic' do
    assert_equal(nil, new_cli.send(:options)[:dynamic])
  end

  test 'accepts dynamic via -D' do
    cli = new_cli(%w(-D))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:dynamic])
  end

  test 'accepts dynamic via --dynamic-schedule' do
    cli = new_cli(%w(--dynamic-schedule))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:dynamic])
  end

  test 'initializes env from the env' do
    cli = new_cli([], { 'RAILS_ENV' => 'flurb' })
    assert_equal('flurb', cli.send(:options)[:env])
  end

  test 'defaults to nil env' do
    assert_equal(nil, new_cli.send(:options)[:env])
  end

  test 'accepts env via -E' do
    cli = new_cli(%w(-E bork))
    cli.parse_options
    assert_equal('bork', cli.send(:options)[:env])
  end

  test 'accepts env via --environment' do
    cli = new_cli(%w(--environment hork))
    cli.parse_options
    assert_equal('hork', cli.send(:options)[:env])
  end

  test 'initializes initializer_path from the env' do
    cli = new_cli([], { 'INITIALIZER_PATH' => 'herp.rb' })
    assert_equal('herp.rb', cli.send(:options)[:initializer_path])
  end

  test 'defaults to nil initializer_path' do
    assert_equal(nil, new_cli.send(:options)[:initializer_path])
  end

  test 'accepts initializer_path via -I' do
    cli = new_cli(%w(-I hambone.rb))
    cli.parse_options
    assert_equal('hambone.rb', cli.send(:options)[:initializer_path])
  end

  test 'accepts initializer_path via --initalizer-path' do
    cli = new_cli(%w(--initializer-path cookies.rb))
    cli.parse_options
    assert_equal('cookies.rb', cli.send(:options)[:initializer_path])
  end

  test 'loads given initilalizer_path' do
    cli = new_cli(%w(--initializer-path fuzzbert.rb))
    cli.expects(:load).with('fuzzbert.rb')
    cli.pre_run
  end

  test 'initializes mute/quiet from the env' do
    cli = new_cli([], { 'QUIET' => '1' })
    assert_equal('1', cli.send(:options)[:mute])
  end

  test 'defaults to unmuted' do
    assert_equal(false, !!new_cli.send(:options)[:mute])
  end

  test 'accepts mute/quiet via -q' do
    cli = new_cli(%w(-q))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:mute])
  end

  test 'accepts mute via --quiet' do
    cli = new_cli(%w(--quiet))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:mute])
  end

  test 'initializes logfile from the env' do
    cli = new_cli([], { 'LOGFILE' => 'derp.log' })
    assert_equal('derp.log', cli.send(:options)[:logfile])
  end

  test 'defaults to nil logfile' do
    assert_equal(nil, new_cli.send(:options)[:logfile])
  end

  test 'accepts logfile via -l' do
    cli = new_cli(%w(-l hurm.out))
    cli.parse_options
    assert_equal('hurm.out', cli.send(:options)[:logfile])
  end

  test 'accepts logfile via --logfile' do
    cli = new_cli(%w(--logfile flam.log))
    cli.parse_options
    assert_equal('flam.log', cli.send(:options)[:logfile])
  end

  test 'initializes logformat from the env' do
    cli = new_cli([], { 'LOGFORMAT' => 'fancy' })
    assert_equal('fancy', cli.send(:options)[:logformat])
  end

  test 'defaults to nil logformat' do
    assert_equal(nil, new_cli.send(:options)[:logformat])
  end

  test 'accepts logformat via -F' do
    cli = new_cli(%w(-F silly))
    cli.parse_options
    assert_equal('silly', cli.send(:options)[:logformat])
  end

  test 'accepts logformat via --logformat' do
    cli = new_cli(%w(--logformat flimsy))
    cli.parse_options
    assert_equal('flimsy', cli.send(:options)[:logformat])
  end

  test 'initializes dynamic from the env' do
    cli = new_cli([], { 'DYNAMIC_SCHEDULE' => '1' })
    assert_equal('1', cli.send(:options)[:dynamic])
  end

  test 'defaults to dynamic=false' do
    assert_equal(false, !!new_cli.send(:options)[:dynamic])
  end

  test 'accepts dynamic via -D' do
    cli = new_cli(%w(-D))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:dynamic])
  end

  test 'accepts dynamic via --dynamic-schedule' do
    cli = new_cli(%w(--dynamic-schedule))
    cli.parse_options
    assert_equal(true, cli.send(:options)[:dynamic])
  end

  test 'initializes app_name from the env' do
    cli = new_cli([], { 'APP_NAME' => 'sprocket' })
    assert_equal('sprocket', cli.send(:options)[:app_name])
  end

  test 'defaults to nil app_name' do
    assert_equal(nil, new_cli.send(:options)[:app_name])
  end

  test 'accepts app_name via -n' do
    cli = new_cli(%w(-n hambone))
    cli.parse_options
    assert_equal('hambone', cli.send(:options)[:app_name])
  end

  test 'accepts app_name via --app-name' do
    cli = new_cli(%w(--app-name flimsy))
    cli.parse_options
    assert_equal('flimsy', cli.send(:options)[:app_name])
  end

  test 'runs Resque::Scheduler' do
    Resque::Scheduler.expects(:run)
    ResqueScheduler::Cli.run!([], {})
  end
end
