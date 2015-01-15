module Athlete
  class Build
    include Logging
    
    @builds = {}
    
    class << self
      attr_accessor :builds
    end
    
    # Define valid properties
    @@valid_properties =  %w{
      name
      registry
      version
    }
    
    def initialize
      @@valid_properties.each do |property|
        self.class.class_eval {
          define_method(property) do |arg|
            instance_variable_set("@#{property}", arg)
            self.class.class_eval{attr_reader property.to_sym}
          end
        }
      end
    end
    
    def setup_dsl_methods
      @@valid_properties.each do |property|
        self.class.class_eval {
          define_method(property) do |arg|
            instance_variable_set("@#{property}", arg)
            self.class.class_eval{attr_reader property.to_sym}
          end
        }
      end
    end
    
    def self.define(name, &block)
      build = Athlete::Build.new
      build.name name
      build.instance_eval(&block)
      build.fill_default_values
      @builds[build.name] = build
    end
    
    def fill_default_values
      @version_method ||= :git_head
    end
    
    def final_image_name
      @final_image_name ||= @registry.nil? ? "#{@name}:#{determined_version}" : "#{@registry}/#{@name}:#{determined_version}"
    end
    
    def determined_version
      case @version
      when :git_head
        return git_tag
      else
        return @version.to_s
      end
    end
    
    # Figure out the short hash of the current HEAD
    def git_tag
      return @git_tag if @git_tag
      @git_tag = `git rev-parse --short HEAD 2>&1`.chomp
      if $? != 0
        raise Athlete::BuildFailedException, "Could not determine git hash of HEAD, output was: #{@git_tag}"
      end
      @git_tag
    end
    
    # Create the image name with a specified git tag
    def image_name_with_specified_version(version)
      @registry.nil? ? "#{@name}:#{version}" : "#{@registry}/#{@name}:#{version}"
    end
    
    def perform(should_push)
      build
      if should_push
        push
      else
        info "Skipping push of image as --no-push was specified"
      end
    end
    
    # Build the Docker image
    def build
      info "Building with image name as: '#{final_image_name}', tagged #{determined_version}"
      command = "docker build -t #{final_image_name} ."
      logged_command = get_loglevel == Logger::INFO  ? 'docker build' : command
      retval = Utils::Subprocess.run command do |stdout, stderr, thread|
        info "[#{logged_command}] [stdout] #{stdout}"
        info "[#{logged_command}] [stderr] #{stderr}" if stderr != nil
      end
      if retval.exitstatus != 0
        raise Athlete::CommandExecutionFailed, "The command #{command} exited with non-zero status #{retval.exitstatus}"
      end
    end
    
    # Push image to remote registry (Docker Hub or private registry)
    def push
      if @registry.nil?
        info "Preparing to push image to the Docker Hub"
      else
        info "Preparing to push image to '#{@registry}'"
      end
      
      command = "docker push #{final_image_name}"
      retval = Utils::Subprocess.run "docker push #{final_image_name}" do |stdout, stderr, thread|
        info "[#{logged_command}] [stdout] #{stdout}"
        info "[#{logged_command}] [stderr] #{stderr}" if stderr != nil
      end
      
      if retval.exitstatus != 0
        raise Athlete::CommandExecutionFailed, "The command #{command} exited with non-zero status #{retval.exitstatus}"
      end
    end
    
    def readable_output
      lines = []
      lines << "  Build name: #{@name}"
      @@valid_properties.sort.each do |property|
        next if property == 'name'
        lines << sprintf("    %-10s: %s", property, instance_variable_get("@#{property}")) if instance_variable_get("@#{property}")
      end
      puts lines.join("\n")
    end
    
  end
end