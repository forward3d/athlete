require 'thor'

module Athlete
  class CLI < Thor
    include Thor::Actions
    include Logging
    
    # Allow specifying a custom path to the config file
    class_option :config, :desc => "Path to config file", :aliases => "-f"
    
    # Verbose (turns loglevel to DEBUG)
    class_option :verbose, :desc => "Output verbose logging", :aliases => "-v", :type => :boolean, :default => false
    
    desc 'list [TYPE]', 'List all builds and/or deployments'
    long_desc <<-LONGDESC
      `athlete list` will show all builds and deployments.
      `athlete list builds` will show only builds, and `athlete list deployments` will
      list only deployments.
    LONGDESC
    def list(type = nil)
      setup
      output_builds if type.nil? || type == 'builds'
      output_deployments if type.nil? || type == 'deployments'
    end
      
    
    desc 'build BUILD_NAME', 'Build and push the Docker image specified by BUILD_NAME'
    long_desc <<-LONGDESC
      `athlete build` will build the named Docker image(s) specified in the build section
      of your Athlete configuration file. It will then push this image to the remote
      registry you have specified, unless you specify the `--no-push` flag (`--push` is
      the default).
    LONGDESC
    method_option :push, :desc => "Specify whether the image should be pushed to the configured registry", :type => :boolean, :default => true
    def build(build_name)
      setup
      
      build = Athlete::Build.builds[build_name]
      if build
        do_build(build, options[:push])
      else
        fatal "Could not locate a build in the configuration named '#{build_name}'"
        exit 1
      end
    end
    
    desc 'deploy DEPLOYMENT_NAME', 'Run the deployment specified by DEPLOYMENT_NAME'
    long_desc <<-LONGDESC
      `athlete deploy` will deploy container(s) (to Marathon) of the Docker image(s) specified in the deployment
      section of your Athlete configuration file.
    LONGDESC
    def deploy(deployment_name)
      setup
      
      deployment = Athlete::Deployment.deployments[deployment_name]
      if deployment
       do_deploy(deployment)
      else
       fatal "Could not locate a deployment in the configuration named '#{deployment_name}'"
       exit 1
      end
    end
    
    private
    
    def setup
      handle_verbose
      load_config
    end
    
    # Basic configuration loading and safety checking of the DSL
    def load_config
      config_file = options[:config] || 'config/athlete.rb'
      if !File.exists?(config_file)
        fatal "Config file '#{config_file}' does not exist or cannot be read"
        exit 1
      end
      debug "Using configuration file at #{config_file}"
      begin
        load config_file
      rescue Exception => e
        fatal "Exception loading the config file - #{e.class}: #{e.message} at #{e.backtrace[0]}"
        exit 1
      end
    end
    
    def handle_verbose
      options[:verbose] ? loglevel(Logger::DEBUG) : loglevel(Logger::INFO)
    end
    
    def do_build(build, should_push)
      info "Beginning build of '#{build.name}'"
      build.perform(should_push)
      info "Build complete"
    end
    
    def do_deploy(deployment)
      info "Beginning deployment of '#{deployment.name}'"
      deployment.perform
      info "Deployment complete"
    end
    
    def output_builds
      puts "Builds"
      Athlete::Build.builds.keys.sort.each do |name|
        Athlete::Build.builds[name].readable_output
      end
    end
    
    def output_deployments
      puts "Deployments"
      Athlete::Deployment.deployments.keys.sort.each do |name|
        Athlete::Deployment.deployments[name].readable_output
      end
    end
    
  end
end