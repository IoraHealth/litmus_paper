require 'open3'

module LitmusPaper
  module Dependency
    class Script
      attr_reader :script_pid

      def initialize(command, options = {})
        @command = command
        @timeout = options.fetch(:timeout, 5)
      end

      def available?
        script_status = script_stdout = script_stderr = nil
        Open3.popen3(@command, :pgroup=>true) do |stdin, stdout, stderr, wait_thr|
          @script_pid = wait_thr.pid
          thstderr = Thread.new { stderr.read }
          thstdout = Thread.new { stdout.read }
          if !wait_thr.join(@timeout) # wait thread does not end within timeout
            kill_and_reap_script(-@script_pid) # kill the process group
            raise Timeout::Error
          end
          script_stderr = thstderr.value
          script_stdout = thstdout.value
          script_status = wait_thr.value
        end
        unless script_status.success?
          LitmusPaper.logger.info("Available check to #{@command} failed with status #{script_status.exitstatus}")
          LitmusPaper.logger.info("Failed stdout: #{script_stdout}")
          LitmusPaper.logger.info("Failed stderr: #{script_stderr}")
        end
        script_status.success?
      rescue Timeout::Error
        LitmusPaper.logger.info("Timeout running command: '#{@command}'")
        false
      rescue => e
        LitmusPaper.logger.info("Available check to #{@uri} failed with #{e.message}")
        false
      end

      def kill_and_reap_script(pid)
        Process.kill(9, pid)
        stop_time = Time.now + 2
        while Time.now < stop_time
          if Process.waitpid(pid, Process::WNOHANG)
            LitmusPaper.logger.info("Reaped PID #{pid}")
            return
          else
            sleep 0.1
          end
        end
        LitmusPaper.logger.error("Unable to reap PID #{pid}")
      rescue Errno::ESRCH
        LitmusPaper.logger.info("Attempted to kill non-existent PID #{pid} (ESRCH)")
      rescue Errno::ECHILD
        LitmusPaper.logger.info("Attempted to reap PID #{pid} but it has already been reaped (ECHILD)")
      end

      def to_s
        "Dependency::Script(#{@command})"
      end
    end
  end
end
