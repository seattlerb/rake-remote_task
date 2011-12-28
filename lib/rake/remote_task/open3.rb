require 'open3'

module Rake::RemoteOpen3
  include Open3

  # Use ssh to execute +command+ on target_host. If +command+ uses sudo, the
  # sudo password will be prompted for then saved for subsequent sudo commands.
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
      inn.close rescue nil
    end
    status = test_status || $?

    unless status.exitstatus == 0 then
      raise(Rake::CommandFailedError.new(status),
            "execution failed with status #{status.exitstatus}: #{cmd.join ' '}")
    end

    result.join
  end

  private

  # Test hook for injecting status (can't set $?)
  def test_status
    nil
  end

end
