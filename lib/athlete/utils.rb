module Athlete
  module Utils
    
    # A moderately decent way of dealing with running commands
    # and coping with stdout/stderr
    class Subprocess
      extend Logging
      def self.run(cmd, &block)
        info "Running command '#{cmd}'"
        log_command = "#{cmd.split(' ')[0]}"
        # see: http://stackoverflow.com/a/1162850/83386
        Open3.popen3(cmd) do |stdin, stdout, stderr, thread|
          # read each stream from a new thread
          { :out => stdout, :err => stderr }.each do |key, stream|
            Thread.new do
              until (line = stream.gets).nil? do
                # yield the block depending on the stream
                if key == :out
                  debug("[#{log_command}] [stdout] #{line}") unless line.nil?
                else
                  debug("[#{log_command}] [stderr] #{line}") unless line.nil?
                end
              end
            end
          end
  
          thread.join # don't exit until the external process is done
          return thread.value
        end
      end
    end
    
  end
end