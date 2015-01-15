module Athlete
  class Deployment
    include Logging
    
    @deployments = {}
    
    class << self
      attr_accessor :deployments
    end
    
    # Define valid properties
    @@valid_properties =  %w{
      name
      marathon_url
      build_name
      image_name
      command
      arguments
      cpus
      memory
      environment_variables
      instances
      minimum_health_capacity
    }
    
    # Define properties that cannot be overridden or inherited
    @@locked_properties = %w{
      name
      marathon_url
      build_name
      image_name
      command
      arguments
      environment_variables
    }
    
    def initialize
      @inherit_properties = []
      @override_properties = []
      setup_dsl_methods
    end
    
    def setup_dsl_methods
      @@valid_properties.each do |property|
        self.class.class_eval {
          
          # Define property settings methods for the DSL
          define_method(property) do |property_value, override_or_inherit = nil|
            instance_variable_set("@#{property}", property_value)
            if not @@locked_properties.include?(property)
              case override_or_inherit
              when :override
                @override_properties << property
              when :inherit
                @inherit_properties << property
              else
                raise Athlete::ConfigurationInvalidException, 
                  "Property '#{property}' of deployment '#{@name}' specified behaviour as '#{override_or_inherit}', which is not one of :override or :inherit"
              end
            end
            self.class.class_eval{attr_reader property.to_sym}
          end
          
        }
      end
    end
    
    def self.define(name, &block)
      deployment = Athlete::Deployment.new
      deployment.name name
      deployment.instance_eval(&block)
      deployment.fill_default_values
      deployment.validate
      deployment.connect_to_marathon
      @deployments[deployment.name] = deployment
    end
    
    def fill_default_values
      if !@instances
        @instances = 1
        @inherit_properties << 'instances'
      end
    end
    
    def validate
      errors = []
      
      # Must specify a Docker image (either from a build or some upstream source)
      errors << "You must set one of image_name or build_name" unless @build_name || @image_name
      
      # If a build name is specified, it must match something in the file
      if @build_name && linked_build.nil?
        errors << "Build name '#{@build_name}' doesn't match a build in the config file"
      end
      
      # Marathon URL is required
      errors << "You must specify marathon_url" unless @marathon_url
      
      # Environment variables must be a hash
      errors << "environment_variables must be a hash" if @environment_variables && !environment_variables.kind_of?(Hash)
      
      
      
      unless errors.empty?
        raise ConfigurationInvalidException, @errors
      end
    end
    
    def connect_to_marathon
      @marathon_client = Marathon::Client.new(@marathon_url)
    end
    
    def perform
      response = deploy_or_update
      @deploy_response = response.parsed_response
      debug "Entire deployment response: #{response.inspect}"
      
      # Check to see if the deployment actually happened
      if response.code == 409
        fatal "Deployment did not start; another deployment is in progress"
        exit 1
      end
      
      info "Polling for deployment state"
      state = poll_for_deploy_state
      case state
      when :retry_exceeded
        fatal "App failed to start on Marathon; cancelling deploy"
        exit 1
      when :complete
        info "App is running on Marathon; deployment complete"
      else
        fatal "App is in unknown state on Marathon"
        exit 1
      end
    end
    
    def deploy_or_update
      if app_running?
        debug "App is running in Marathon; performing a warm deploy"
        prepare_for_warm_deploy
        return @marathon_client.update(@name, marathon_json)
      else
        debug "App is not running in Marathon; performing a cold deploy"
        prepare_for_cold_deploy
        return @marathon_client.start(@name, marathon_json)
      end
    end
    
    # Poll Marathon to see if the deploy has completed for the
    # given deployed version
    def poll_for_deploy_state
      debug "Entering deploy state polling"
      while (not deployment_completed?) && (not retry_exceeded?)
        if has_task_failures?
          warn "Task failures have occurred during the deploy attempt - this deploy may not succeed"
          sleep 1
          increment_retry
        else
          debug "Deploy still in progress with no task failures; sleeping and retrying"
          sleep 1
          increment_retry
        end
      end
      
      # We bailed because we exceeded retry or the deploy completed, determine
      # which of these states it is
      deployment_completed? ? :complete : :retry_exceeded
    end
    
    def deployment_completed?
      @marathon_client.find_deployment_by_name(@name) == nil
    end
    
    def retry_exceeded?
      @retry_count == 10
    end
    
    def increment_retry
      @retry_count ||= 0
      @retry_count = @retry_count + 1
    end
    
    def has_task_failures?
      app_config = @marathon_client.find(@name)
      return false if app_config.parsed_response['app']['lastTaskFailure'].nil?
      app_config.parsed_response['app']['lastTaskFailure']['version'] == @deploy_response['version']
    end
    
    # A 'warm' deploy is one where the app is running in Marathon and 
    # we're making changes to it. For each declared configuration property, 
    # determine whether it will be always inserted into the remote configuration
    # (:override) or not (:inherit). Think of :override as "Athlete is 
    # authoritative for this property", and :inherit as "Marathon is
    # authoritative for this property".
    # The way this works in practice is we unset any instance variables
    # that are specified as "inherit", so that when the Marathon JSON
    # is generated by `to_marathon_json` they do not appear in the final
    # deployment JSON.
    def prepare_for_warm_deploy
      @inherit_properties.each do |property|
        debug "Property '#{property}' is specified as :inherit; not supplying to Marathon"
        instance_variable_set("@#{property}", nil)
      end
    end
    
    # A 'cold' deploy is one where the app is not running in Marathon.
    # We have to do additional validation to ensure we can deploy the app, since
    # we don't have a set of valid parameters in Marathon.
    def prepare_for_cold_deploy
      errors = []
      errors << "You must specify the parameter 'cpus'" unless @cpus
      errors << "You must specify the parameter 'memory'" unless @memory
      unless errors.empty?
        raise ConfigurationInvalidException, @errors
      end
    end
    
    # Locate the linked build
    def linked_build
      @build_name ? Athlete::Build.builds[@build_name] : nil
    end
    
    # Find the app if it's already in Marathon (if it's not there, we get nil)
    def get_running_config
      if @running_config
        return @running_config
      else
        response = @marathon_client.find(@name)
        @running_config = response.error? ? nil : response.parsed_response
        debug "Retrieved running Marathon configuration: #{@running_config}"
        return @running_config
      end
    end
    
    def app_running?
      get_running_config != nil
    end
    
    def marathon_json
      json = {}
      
      json['id'] = @name
      json['cmd'] = @command if @command
      json['args'] = @arguments if @arguments
      json['cpus'] = @cpus if @cpus
      json['mem'] = @memory if @memory
      json['env'] = @environment_variables if @environment_variables
      json['instances'] = @instances if @instances
      if @minimum_health_capacity
        json['upgradeStrategy'] = {
          'minimumHealthCapacity' => @minimum_health_capacity
        }
      end
      
      if @image_name || @build_name
        image = @image_name || linked_build.final_image_name
        json['container'] = {
          'type' => 'DOCKER',
          'docker' => {
            'image' => image,
            'network' => 'BRIDGE'
          }
        }
      end
      debug("Generated Marathon JSON: #{json.to_json}")
      json
    end
    
    def readable_output
      lines = []
      lines << "  Deployment name: #{@name}"
      @@valid_properties.sort.each do |property|
        next if property == 'name'
        lines << sprintf("    %-26s: %s", property, instance_variable_get("@#{property}")) if instance_variable_get("@#{property}")
      end
      puts lines.join("\n")
    end
    
  end
end