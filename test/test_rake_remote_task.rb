require 'rake/test_case'

class TestRakeRemoteTask < Rake::TestCase
  def teardown
    Object.send :remove_method, :old_domain if
      Object.private_instance_methods.include? :old_domain
  end

  def test_enhance
    util_set_hosts
    body = Proc.new { 5 }
    task = @rake.remote_task(:some_task => :foo, &body)
    action = Rake::RemoteTask::Action.new(task, body)
    assert_equal [action], task.remote_actions
    assert_equal task, action.task
    assert_equal ["foo"], task.prerequisites
  end

  def test_enhance_with_no_task_body
    util_set_hosts
    util_setup_task
    assert_equal [], @task.remote_actions
    assert_equal [], @task.prerequisites
  end

  def test_execute
    util_set_hosts
    set :some_variable, 1
    set :can_set_nil, nil
    set :lies_are, false
    x = 5
    task = @rake.remote_task(:some_task) do
      @lock.synchronize do
        x += some_variable
      end
    end
    task.execute nil
    assert_equal 1, task.send(:some_variable)
    assert_equal 7, x
    assert task.send(:can_set_nil).nil?
    assert_equal false, task.send(:lies_are)
  end

  def test_set_false
    set :can_set_nil, nil
    set :lies_are, false

    assert_equal nil,   task.send(:can_set_nil)

    assert_equal false, task.send(:lies_are)
    assert_equal false, Rake::RemoteTask.fetch(:lies_are)
  end


  def test_fetch_false
    assert_equal false, Rake::RemoteTask.fetch(:unknown, false)
  end

  def test_execute_exposes_target_host
    host "app.example.com", :app
    task = remote_task(:target_task) { set(:test_target_host, target_host) }
    task.execute nil
    assert_equal "app.example.com", Rake::RemoteTask.fetch(:test_target_host)
  end

  def test_execute_with_no_hosts
    @rake.host "app.example.com", :app
    t = @rake.remote_task(:flunk, :roles => :db) { flunk "should not have run" }
    e = assert_raises(Rake::ConfigurationError) { t.execute nil }
    assert_equal "No target hosts specified on task flunk for roles [:db]",
                 e.message
  end

  def test_execute_with_no_roles
    t = @rake.remote_task(:flunk, :roles => :junk) { flunk "should not have run" }
    e = assert_raises(Rake::ConfigurationError) { t.execute nil }
    assert_equal "No target hosts specified on task flunk for roles [:junk]",
                 e.message
  end

  def test_execute_with_roles
    util_set_hosts
    set :some_variable, 1
    x = 5
    task = @rake.remote_task(:some_task, :roles => :db) { x += some_variable }
    task.execute nil
    assert_equal 1, task.send(:some_variable)
    assert_equal 6, x
  end

  def test_rsync
    util_setup_task
    @task.target_host = "app.example.com"

    assert_silent do
      @task.rsync 'localfile', 'host:remotefile'
    end

    commands = @task.commands

    assert_equal 1, commands.size, 'not enough commands'
    assert_equal(%w[rsync -azP --delete localfile host:remotefile],
                 commands.first)
  end

  def test_rsync_fail
    util_setup_task
    @task.target_host = "app.example.com"
    @task.action = proc { false }

    e = assert_raises Rake::CommandFailedError do
      assert_silent do
        @task.rsync 'local', 'host:remote'
      end
    end
    exp = "execution failed: rsync -azP --delete local host:remote"
    assert_equal exp, e.message
  end

  def test_rsync_deprecation
    util_setup_task
    @task.target_host = "app.example.com"

    out, err = capture_io do
      @task.rsync 'localfile', 'remotefile'
    end

    commands = @task.commands

    assert_equal 1, commands.size, 'not enough commands'
    assert_equal(%w[rsync -azP --delete localfile app.example.com:remotefile],
                 commands.first)

    assert_equal("rsync deprecation: pass target_host:remote_path explicitly\n",
                 err)
    assert_empty out
    # flunk "not yet"
  end

  def test_get
    util_setup_task
    @task.target_host = "app.example.com"

    assert_silent do
      @task.get 'tmp', "remote1", "remote2"
    end

    commands = @task.commands

    expected = %w[rsync -azP --delete app.example.com:remote1 app.example.com:remote2 tmp]

    assert_equal 1, commands.size
    assert_equal expected, commands.first
  end

  def test_put
    util_setup_task
    @task.target_host = "app.example.com"

    assert_silent do
      @task.put 'dest' do
        "whatever"
      end
    end

    commands = @task.commands

    expected  = %w[rsync -azP --delete HAPPY app.example.com:dest]
    commands.first[3] = 'HAPPY'

    assert_equal 1, commands.size
    assert_equal expected, commands.first
  end

  def test_run
    util_setup_task
    @task.output << "file1\nfile2\n"
    @task.target_host = "app.example.com"
    result = nil

    out, err = capture_io do
      result = @task.run("ls")
    end

    commands = @task.commands

    assert_equal 1, commands.size, 'not enough commands'
    assert_equal ["ssh", "app.example.com", "ls"],
                 commands.first, 'app'
    assert_equal "file1\nfile2\n", result

    assert_equal "file1\nfile2\n", out
    assert_equal '', err
  end

  def test_run_dir
    util_setup_task
    @task.target_host = "app.example.com:/www/dir1"

    @task.run("ls")

    commands = @task.commands

    assert_equal 1, commands.size, 'not enough commands'
    assert_equal [["ssh", "app.example.com", "cd /www/dir1 && ls"]], commands
  end

  def test_run_failing_command
    util_set_hosts
    util_setup_task
    @task.input = StringIO.new "file1\nfile2\n"
    @task.target_host =  'app.example.com'
    @task.action = proc { 1 }

    e = assert_raises(Rake::CommandFailedError) { @task.run("ls") }
    assert_equal "execution failed with status 1: ssh app.example.com ls", e.message

    assert_equal 1, @task.commands.size
  end

  def test_run_sudo
    util_setup_task
    @task.output << "file1\nfile2\n"
    @task.error << 'Password:'
    @task.target_host = "app.example.com"
    def @task.sudo_password() "my password" end # gets defined by set
    result = nil

    out, err = capture_io do
      result = @task.run("sudo ls")
    end

    commands = @task.commands

    assert_equal 1, commands.size, 'not enough commands'
    assert_equal ['ssh', 'app.example.com', 'sudo ls'],
                 commands.first

    assert_equal "my password\n", @task.input.string

    # WARN: Technically incorrect, the password line should be
    # first... this is an artifact of changes to the IO code in run
    # and the fact that we have a very simplistic (non-blocking)
    # testing model.
    assert_equal "file1\nfile2\nPassword:\n", result

    assert_equal "file1\nfile2\n", out
    assert_equal "Password:\n", err
  end

  def test_sudo
    util_setup_task
    @task.target_host = "app.example.com"
    @task.sudo "ls"

    commands = @task.commands

    assert_equal 1, commands.size, 'wrong number of commands'
    assert_equal ["ssh", "app.example.com", "sudo -p Password: ls"],
                 commands.first, 'app'
  end

  def test_append
    append :some_array, 1
    assert_equal [1], some_array
  end
end
