require 'uri'

module Marathon
  class Client
    include HTTParty

    headers(
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    )

    query_string_normalizer proc { |query| MultiJson.dump(query) }
    maintain_method_across_redirects
    default_timeout 5

    EDITABLE_APP_ATTRIBUTES = [
      :cmd, :constraints, :container, :cpus, :env, :executor, :id, :instances,
      :mem, :ports, :uris]

    def initialize(host = nil, user = nil, pass = nil, proxy = nil)
      @host = host || ENV['MARATHON_HOST'] || 'http://localhost:8080'
      @default_options = {}

      if user && pass
        @default_options[:basic_auth] = {:username => user, :password => pass}
      end

      if proxy
        @default_options[:http_proxyaddr] = proxy[:addr]
        @default_options[:http_proxyport] = proxy[:port]
        @default_options[:http_proxyuser] = proxy[:user] if proxy[:user]
        @default_options[:http_proxypass] = proxy[:pass] if proxy[:pass]
      end
    end

    def list
      wrap_request(:get, '/v2/apps')
    end
    
    def find(id)
      wrap_request(:get, "/v2/apps/#{id}")
    end
    
    def list_tasks(id)
      wrap_request(:get, URI.escape("/v2/apps/#{id}/tasks"))
    end

    def search(id = nil, cmd = nil)
      params = {}
      params[:id] = id unless id.nil?
      params[:cmd] = cmd unless cmd.nil?

      wrap_request(:get, "/v2/apps?#{query_params(params)}")
    end
    
    def deployments
      wrap_request(:get, "/v2/deployments")
    end
    
    def find_deployment_by_name(name)
      wrap_request(:get, "/v2/deployments").parsed_response.find do |deployment|
        deployment['affectedApps'].include?("/#{name}")
      end
    end

    def endpoints(id = nil)
      if id.nil?
        url = "/v2/tasks"
      else
        url = "/v2/apps/#{id}/tasks"
      end

      wrap_request(:get, url)
    end

    def start(id, opts)
      body = opts.dup
      body[:id] = id
      wrap_request(:post, '/v2/apps/', :body => body)
    end
    
    def update(id, opts)
      body = opts.dup
      body[:id] = id
      wrap_request(:put, "/v2/apps/#{id}", :body => body)
    end

    def scale(id, num_instances)
      # Fetch current state and update only the 'instances' attribute. Since the
      # API only supports PUT, the full representation of the app must be
      # supplied to update even just a single attribute.
      app = wrap_request(:get, "/v2/apps/#{id}").parsed_response['app']
      app.select! {|k, v| EDITABLE_APP_ATTRIBUTES.include?(k)}

      app[:instances] = num_instances
      wrap_request(:put, "/v2/apps/#{id}", :body => app)
    end

    def kill(id)
      wrap_request(:delete, "/v2/apps/#{id}")
    end

    def kill_tasks(appId, params = {})
      if params[:task_id].nil?
        wrap_request(:delete, "/v2/apps/#{appId}/tasks?#{query_params(params)}")
      else
        query = params.clone
        task_id = query[:task_id]
        query.delete(:task_id)

        wrap_request(:delete, "/v2/apps/#{appId}/tasks/#{task_id}?#{query_params(query)}")
      end
    end

    private

    def wrap_request(method, url, options = {})
      options = @default_options.merge(options)
      http = self.class.send(method, @host + url, options)
      Marathon::Response.new(http)
    rescue => e
      Marathon::Response.error(e.message)
    end

    def query_params(hash)
      hash = hash.select { |k,v| !v.nil? }
      URI.escape(hash.map { |k,v| "#{k}=#{v}" }.join('&'))
    end
  end
end
