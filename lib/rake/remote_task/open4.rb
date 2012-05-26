require 'open4'

##
# Implementation of +run+ using Open4. This uses fork underneath and
# therefore only works where fork works (jruby is a notable exception,
# see RemoteOpen3)
module Rake::RemoteOpen4
  include Open4

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

    pid, inn, out, err = popen4(*cmd)

    inn.sync   = true
    streams    = [out, err]
    out_stream = {
      out => $stdout,
      err => $stderr,
    }

    # Handle process termination ourselves
    status = nil
    Thread.start do
      status = Process.waitpid2(pid).last
    end

    until streams.empty? do
      # don't busy loop
      selected, = select streams, nil, nil, 0.1

      next if selected.nil? or selected.empty?

      selected.each do |stream|
        if stream.eof? then
          streams.delete stream if status # we've quit, so no more writing
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

    unless status.success? then
      raise(Rake::CommandFailedError.new(status),
            "execution failed with status #{status.exitstatus}: #{cmd.join ' '}")
    end

    result.join
  ensure
    inn.close rescue nil
    out.close rescue nil
    err.close rescue nil
  end

end
