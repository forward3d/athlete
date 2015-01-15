require 'thor'

module Athlete
  class CLI < Thor
    include Thor::Actions
    include Logging
    
    # Allow specifying a custom path to the config file
    class_option :config, :desc => "Path to config file", :aliases => "-f"
    
    # Verbose (turns loglevel to DEBUG)
    class_option :verbose, :desc => "Output verbose logging", :aliases => "-v", :type => :boolean, :default => false
    
    desc 'build [BUILD_NAME]', 'Build and push all Docker images or only the image specified by BUILD_NAME'
    long_desc <<-LONGDESC
      `athlete build` will build the Docker image(s) specified in the build section
      of your Athlete configuration file. It will then push this image to the remote
      registry you have specified, unless you specify the `--no-push` flag (`--push` is
      the default).
      
      If you want to specify a single build to run, run `athlete build [BUILD_NAME]`, where BUILD_NAME
      is the name of the build in your configuration file.
    LONGDESC
    method_option :push, :desc => "Specify whether the image should be pushed to the configured registry", :type => :boolean, :default => true
    def build(build_name = nil)
      setup
      
      # Handle a single build
      if build_name
        build = Athlete::Build.builds[build_name]
        if build
          do_build(build, options[:push])
        else
          fatal "Could not locate a build in the configuration named '#{build_name}'"
          exit 1
        end
      else
        # Run all builds
        Athlete::Build.builds.each_pair do |name, build|
          do_build(build, options[:push])
        end
      end
    end
    
    desc 'deploy [DEPLOYMENT_NAME]', 'Run all specified deployments or only the deployment specified by DEPLOYMENT_NAME'
    long_desc <<-LONGDESC
      `athlete deploy` will deploy container(s) (to Marathon) of the Docker image(s) specified in the deployment
      section of your Athlete configuration file.
      
      If you want to deploy a single container, run `athlete deploy [DEPLOYMENT_NAME]`, where DEPLOYMENT_NAME
      is the name of the deployment in your configuration file.
    LONGDESC
    def deploy(deployment_name = nil)
      setup
      
      # Handle a single deployment request
      if deployment_name
        deployment = Athlete::Deployment.deployments[deployment_name]
        if deployment
          do_deploy(deployment)
        else
          fatal "Could not locate a deployment in the configuration named '#{deployment_name}'"
          exit 1
        end
      else
        # All deployments required
        Athlete::Deployment.deployments.each_pair do |name, deployment|
          do_deploy(deployment)
        end
      end
    end
    
    private
    
    def setup
      load 'config/athlete.rb'
      handle_verbose
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
    
  end
end