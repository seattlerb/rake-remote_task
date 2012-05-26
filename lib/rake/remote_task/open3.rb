require 'open3'

##
# Implementation of +run+ using stdlib Open3. Currently this is only
# viable on JRuby where the exit status may be obtained. By comparison
# open4 requires a fork which isn't available on JRuby.
module Rake::RemoteOpen3
  include Open3

  ##
  # Use ssh to execute +command+ on target_host. If +command+ uses
  # sudo, the sudo password will be prompted for then saved for
  # subsequent sudo commands.
  def run command
    command = "cd #{target_dir} && #{command}" if target_dir
    cmd     = [ssh_cmd, ssh_flags, target_host, command].flatten
    result  = []

    trace = [ssh_cmd, ssh_flags, target_host, "'#{command}'"].flatten.join(' ')
    warn trace if $TRACE

    popen3(*cmd) do |inn,out,err|

      inn.sync   = true
      streams    = [out, err]
      out_stream = {
        out => $stdout,
        err => $stderr,
      }

      until streams.empty? do
        # don't busy loop
        selected, = select(streams, nil, nil, 0.1)

        next if selected.nil? or selected.empty?

        selected.each do |stream|
          if stream.eof? then
            streams.delete stream
            next
          end

          data = stream.readpartial(1024)
          out_stream[stream].write data

          if stream == err and data =~ sudo_prompt then
            inn.puts sudo_password
            data << "\n"
            $stderr.write "\n"
          end

          result << data
        end
      end

      # Make sure an open input stream doesn't keep the process
      # running. The others are closed on exit from block by popen3
      # itself.
      inn.close rescue nil
    end

    # MRI popen3 uses double fork and thus has no way to set `$?`, see:
    #
    #   http://bugs.ruby-lang.org/issues/1287
    #
    # However the `$?` is available after the popen3 {} (block form
    # only) in the non-forking jruby implementation. Good thing since
    # waitpid* isn't reliable here.
    #
    # test_status will be non-null in test
    status = test_status || $?

    unless status.exitstatus == 0 then
      raise(Rake::CommandFailedError.new(status),
            "execution failed with status #{status.exitstatus}: #{cmd.join ' '}")
    end

    result.join
  end

  private

  ##
  # Test hook for injecting status (can't set $?)
  def test_status
    nil
  end

end
