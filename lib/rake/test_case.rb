require 'minitest/autorun'
require 'rake'
require 'rake/remote_task'
require 'stringio'

class StringIO
  def readpartial(size) read end # suck!
end

module Process
  def self.expected status
    @@expected ||= []
    @@expected << status
  end

  class << self
    alias :waitpid2_old :waitpid2

    def waitpid2(pid)
      [ @@expected.shift ]
    end
  end
end

class Rake::RemoteTask
  attr_accessor :commands, :action, :input, :output, :error

  Status = Struct.new :exitstatus

  class Status
    def success?() exitstatus == 0 end
  end

  def system *command
    @commands << command
    self.action ? self.action[command.join(' ')] : true
  end

  def popen4 *command
    @commands << command

    @input = StringIO.new
    out = StringIO.new @output.shift.to_s
    err = StringIO.new @error.shift.to_s

    raise if block_given?

    status = self.action ? self.action[command.join(' ')] : 0
    Process.expected Status.new(status)

    return 42, @input, out, err
  end

  def select reads, writes, errs, timeout
    [reads, writes, errs]
  end
end

class Rake::TestCase < MiniTest::Unit::TestCase
  include Rake::DSL if defined? Rake::DSL

  def setup
    @rake = Rake::RemoteTask
    @rake.reset
    Rake.application.clear
    @task_count = Rake.application.tasks.size
    @rake.set :domain, "example.com"
    @lock = Mutex.new
  end

  def util_set_hosts
    @rake.host "app.example.com", :app
    @rake.host "db.example.com", :db
  end

  def util_setup_task(options = {})
    @task = @rake.remote_task :test_task, options
    @task.commands = []
    @task.output   = []
    @task.error    = []
    @task.action   = nil
    @task
  end
end
