require 'rubygems'
require 'rake'
require 'thread'

$TESTING ||= false
$TRACE = Rake.application.options.trace
$-w = true if $TRACE # asshat, don't mess with my warn.

[
 ["Thread.current[:task]", :get, :put, :rsync, :run, :sudo, :target_host],
 ["Rake::RemoteTask",      :host, :remote_task, :role, :set]
].each do |methods|
  receiver = methods.shift
  methods.each do |method|
    eval "def #{method} *args, &block; #{receiver}.#{method}(*args, &block);end"
  end
end

module Rake
  ##
  # Base error class for all Vlad errors.
  class Error < RuntimeError; end

  ##
  # Raised when you have incorrectly configured Vlad.
  class ConfigurationError < Error; end

  ##
  # Raised when a remote command fails.
  class CommandFailedError < Error
    attr_reader :status
    def initialize( status )
      @status = status
    end
  end

  ##
  # Raised when an environment variable hasn't been set.
  class FetchError < Error; end
end

##
# Rake::RemoteTask is a subclass of Rake::Task that adds
# remote_actions that execute in parallel on multiple hosts via ssh.

class Rake::RemoteTask < Rake::Task

  VERSION = "2.0.6"

  if RUBY_PLATFORM =~ /java/
    require 'rake/remote_task/open3'
    include Rake::RemoteOpen3
  else
    require 'rake/remote_task/open4'
    include Rake::RemoteOpen4
  end

  @@current_roles = []

  ##
  # Options for execution of this task.

  attr_accessor :options

  ##
  # The host this task is running on during execution.

  attr_reader :target_host

  ##
  # The directory on the host this task is running in during execution.

  attr_reader :target_dir

  ##
  # An Array of Actions this host will perform during execution. Use
  # enhance to add new actions to a task.

  attr_reader :remote_actions

  def self.current_roles
    @@current_roles
  end

  ##
  # Create a new task named +task_name+ attached to Rake::Application +app+.

  def initialize(task_name, app)
    super

    @remote_actions = []
    @happy = false # used for deprecation warnings on get/put/rsync
  end

  ##
  # Add a local action to this task. This calls Rake::Task#enhance.

  alias_method :original_enhance, :enhance

  ##
  # Add remote action +block+ to this task with dependencies +deps+. See
  # Rake::Task#enhance.

  def enhance(deps=nil, &block)
    original_enhance(deps) # can't use super because block passed regardless.
    @remote_actions << Action.new(self, block) if block_given?
    self
  end

  ##
  # Execute this action. Local actions will be performed first, then remote
  # actions will be performed in parallel on each host configured for this
  # RemoteTask.

  def execute(args = nil)
    raise(Rake::ConfigurationError,
          "No target hosts specified on task #{self.name} for roles #{options[:roles].inspect}") unless
      defined_target_hosts?

    super args

    @remote_actions.each { |act| act.execute(target_hosts, self, args) }
  end

  ##
  # Pull +files+ from the remote +host+ using rsync to +local_dir+.
  # TODO: what if role has multiple hosts & the files overlap? subdirs?

  def get local_dir, *files
    @happy = true
    host = target_host
    rsync files.map { |f| "#{host}:#{f}" }, local_dir
    @happy = false
  end

  ##
  # Copy a (usually generated) file to +remote_path+. Contents of block
  # are copied to +remote_path+ and you may specify an optional
  # base_name for the tempfile (aids in debugging).

  def put remote_path, base_name = File.basename(remote_path)
    require 'tempfile'
    Tempfile.open base_name do |fp|
      fp.puts yield
      fp.flush
      @happy = true
      rsync fp.path, "#{target_host}:#{remote_path}"
      @happy = false
    end
  end

  ##
  # Execute rsync with +args+. Tacks on pre-specified +rsync_cmd+ and
  # +rsync_flags+.
  #
  # Favor #get and #put for most tasks. Old-style direct use where the
  # target_host was implicit is now deprecated.

  def rsync *args
    unless @happy || args[-1] =~ /:/ then
      warn "rsync deprecation: pass target_host:remote_path explicitly"
      args[-1] = "#{target_host}:#{args[-1]}"
    end

    cmd    = [rsync_cmd, rsync_flags, args].flatten.compact
    cmdstr = cmd.join ' '

    warn cmdstr if $TRACE

    success = system(*cmd)

    raise Rake::CommandFailedError.new($?), "execution failed: #{cmdstr}" unless success
  end

  ##
  # Returns an Array with every host configured.

  def self.all_hosts
    hosts_for(roles.keys)
  end

  ##
  # The default environment values. Used for resetting (mostly for
  # tests).

  def self.default_env
    @@default_env
  end

  def self.per_thread
    @@per_thread
  end

  ##
  # The vlad environment.

  def self.env
    @@env
  end

  ##
  # Fetches environment variable +name+ from the environment using
  # default +default+.

  def self.fetch name, default = nil
    name = name.to_s if Symbol === name
    if @@env.has_key? name then
      protect_env(name) do
        v = @@env[name]
        v = @@env[name] = v.call if Proc === v unless per_thread[name]
        v = v.call if Proc === v
        v
      end
    elsif default || default == false
      v = @@env[name] = default
    else
      raise Rake::FetchError
    end
  end

  ##
  # Add host +host_name+ that belongs to +roles+. Extra arguments may
  # be specified for the host as a hash as the last argument.
  #
  # host is the inversion of role:
  #
  #   host 'db1.example.com', :db, :master_db
  #
  # Is equivalent to:
  #
  #   role :db, 'db1.example.com'
  #   role :master_db, 'db1.example.com'

  def self.host host_name, *roles
    opts = Hash === roles.last ? roles.pop : {}

    roles.each do |role_name|
      role role_name, host_name, opts.dup
    end
  end

  ##
  # Returns an Array of all hosts in +roles+.

  def self.hosts_for *roles
    roles.flatten.map { |r|
      self.roles[r].keys
    }.flatten.uniq.sort
  end

  def self.mandatory name, desc # :nodoc:
    self.set(name) do
      raise(Rake::ConfigurationError,
            "Please specify the #{desc} via the #{name.inspect} variable")
    end
  end

  ##
  # Ensures exclusive access to +name+.

  def self.protect_env name # :nodoc:
    @@env_locks[name].synchronize do
      yield
    end
  end

  ##
  # Adds a remote task named +name+ with options +options+ that will
  # execute +block+.

  def self.remote_task name, *args, &block
    options = (Hash === args.last) ? args.pop : {}
    t = Rake::RemoteTask.define_task(name, *args, &block)
    options[:roles] = Array options[:roles]
    options[:roles] |= @@current_roles
    t.options = options
    t
  end

  ##
  # Ensures +name+ does not conflict with an existing method.

  def self.reserved_name? name # :nodoc:
    !@@env.has_key?(name.to_s) && self.respond_to?(name)
  end

  ##
  # Resets vlad, restoring all roles, tasks and environment variables
  # to the defaults.

  def self.reset
    @@def_role_hash = {}                # official default role value
    @@env           = {}
    @@tasks         = {}
    @@roles         = Hash.new { |h,k| h[k] = @@def_role_hash }
    @@env_locks     = Hash.new { |h,k| h[k] = Mutex.new }

    @@default_env.each do |k,v|
      case v
      when Symbol, Fixnum, nil, true, false, 42 then # ummmm... yeah. bite me.
        @@env[k] = v
      else
        @@env[k] = v.dup
      end
    end
  end

  ##
  # Adds role +role_name+ with +host+ and +args+ for that host.
  # TODO: merge:
  # Declare a role and assign a remote host to it. Equivalent to the
  # <tt>host</tt> method; provided for capistrano compatibility.

  def self.role role_name, host = nil, args = {}
    if block_given? then
      raise ArgumentError, 'host not allowed with block' unless host.nil?

      begin
        current_roles << role_name
        yield
      ensure
        current_roles.delete role_name
      end
    else
      raise ArgumentError, 'host required' if host.nil?

      [*host].each do |hst|
        raise ArgumentError, "invalid host: #{hst}" if hst.nil? or hst.empty?
      end
      @@roles[role_name] = {} if @@def_role_hash.eql? @@roles[role_name]
      @@roles[role_name][host] = args
    end
  end

  ##
  # The configured roles.

  def self.roles
    host domain, :app, :web, :db if @@roles.empty?

    @@roles
  end

  ##
  # Set environment variable +name+ to +value+ or +default_block+.
  #
  # If +default_block+ is defined, the block will be executed the
  # first time the variable is fetched, and the value will be used for
  # every subsequent fetch.

  def self.set name, value = nil, &default_block
    raise ArgumentError, "cannot provide both a value and a block" if
      value and default_block unless
      value == :per_thread
    raise ArgumentError, "cannot set reserved name: '#{name}'" if
      Rake::RemoteTask.reserved_name?(name) unless $TESTING

    name = name.to_s

    Rake::RemoteTask.per_thread[name] = true if
      default_block && value == :per_thread

    Rake::RemoteTask.default_env[name] = Rake::RemoteTask.env[name] =
      default_block || value

    if Object.public_instance_methods.include? name.to_sym then
      Object.send :alias_method, :"old_#{name}", name
    end

    Object.send :define_method, name do
      Rake::RemoteTask.fetch name
    end
  end

  ##
  # Sets all the default values. Should only be called once. Use reset
  # if you need to restore values.

  def self.set_defaults
    @@default_env ||= {}
    @@per_thread  ||= {}
    self.reset

    mandatory :repository, "repository path"
    mandatory :deploy_to,  "deploy path"
    mandatory :domain,     "server domain"

    simple_set(:deploy_timestamped, true,
               :deploy_via,         :export,
               :keep_releases,      5,
               :rake_cmd,           "rake",
               :revision,           "head",
               :rsync_cmd,          "rsync",
               :rsync_flags,        ['-azP', '--delete'],
               :ssh_cmd,            "ssh",
               :ssh_flags,          [],
               :sudo_cmd,           "sudo",
               :sudo_flags,         ['-p Password:'],
               :sudo_prompt,        /^Password:/,
               :umask,              '02',
               :mkdirs,             [],
               :shared_paths,       {},
               :perm_owner,         nil,
               :perm_group,         nil)

    set(:current_release)    { File.join(releases_path, releases[-1]) }
    set(:latest_release)     {
      deploy_timestamped ? release_path : current_release
    }
    set(:previous_release)   { File.join(releases_path, releases[-2]) }
    set(:release_name)       { Time.now.utc.strftime("%Y%m%d%H%M%S") }
    set(:release_path)       { File.join(releases_path, release_name) }
    set(:releases)           { task.run("ls -x #{releases_path}").split.sort }

    set_path :current_path,  "current"
    set_path :releases_path, "releases"
    set_path :scm_path,      "scm"
    set_path :shared_path,   "shared"

    set(:sudo_password) do
      state = `stty -g`

      raise Rake::Error, "stty(1) not found" unless $?.success?

      begin
        system "stty -echo"
        $stdout.print "sudo password: "
        $stdout.flush
        sudo_password = $stdin.gets
        $stdout.puts
      ensure
        system "stty #{state}"
      end
      sudo_password
    end
  end

  def self.set_path(name, subdir) # :nodoc:
    set(name) { File.join(deploy_to, subdir) }
  end

  def self.simple_set(*args) # :nodoc:
    args = Hash[*args]
    args.each do |k, v|
      set k, v
    end
  end

  ##
  # The Rake::RemoteTask executing in this Thread.

  def self.task
    Thread.current[:task]
  end

  ##
  # The configured Rake::RemoteTasks.

  def self.tasks
    @@tasks
  end

  ##
  # Execute +command+ under sudo using run.

  def sudo command
    run [sudo_cmd, sudo_flags, command].flatten.compact.join(" ")
  end

  ##
  # Sets the target host. Allows you to set an optional directory
  # using the format:
  #
  #    host.domain:/dir

  def target_host= host
    if host =~ /^(.+):(.+?)$/
      @target_host = $1
      @target_dir  = $2
    else
      @target_host = host
      @target_dir  = nil
    end
  end

  ##
  # The hosts this task will execute on. The hosts are determined from
  # the role this task belongs to.
  #
  # The target hosts may be overridden by providing a comma-separated
  # list of commands to the HOSTS environment variable:
  #
  #   rake my_task HOSTS=app1.example.com,app2.example.com

  def target_hosts
    if hosts = ENV["HOSTS"] then
      hosts.strip.gsub(/\s+/, '').split(",")
    else
      roles = Array options[:roles]

      if roles.empty? then
        Rake::RemoteTask.all_hosts
      else
        Rake::RemoteTask.hosts_for roles
      end
    end
  end

  ##
  # Similar to target_hosts, but returns true if user defined any hosts, even
  # an empty list.

  def defined_target_hosts?
    return true if ENV["HOSTS"]
    roles = Array options[:roles]
    return true if roles.empty?
    # borrowed from hosts_for:
    roles.flatten.each { |r|
      return true unless @@def_role_hash.eql? Rake::RemoteTask.roles[r]
    }
    return false
  end

  ##
  # Action is used to run a task's remote_actions in parallel on each
  # of its hosts. Actions are created automatically in
  # Rake::RemoteTask#enhance.

  class Action

    ##
    # The task this action is attached to.

    attr_reader :task

    ##
    # The block this action will execute.

    attr_reader :block

    ##
    # An Array of threads, one for each host this action executes on.

    attr_reader :workers

    ##
    # Creates a new Action that will run +block+ for +task+.

    def initialize task, block
      @task  = task
      @block = block
      @workers = ThreadGroup.new
    end

    def == other # :nodoc:
      return false unless Action === other
      block == other.block && task == other.task
    end

    ##
    # Execute this action on +hosts+ in parallel. Returns when block
    # has completed for each host.

    def execute hosts, task, args
      hosts.each do |host|
        t = task.clone
        t.target_host = host
        thread = Thread.new(t) do |task2|
          Thread.current[:task] = task2
          case block.arity
          when 1
            block.call task2
          else
            block.call task2, args
          end
          Thread.current[:task] = nil
        end
        @workers.add thread
      end
      @workers.list.each { |thr| thr.join }
    end
  end
end

Rake::RemoteTask.set_defaults
