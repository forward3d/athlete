module Marathon
  class Response

    # TODO make this attr_reader and set the error some other way
    attr_accessor :error

    def initialize(http)
      @http = http
      @error = error_message_from_response
    end

    def success?
      @http && @http.success?
    end

    def error?
      !success?
    end

    def parsed_response
      @http && @http.parsed_response
    end

    def self.error(message)
      error = new(nil)
      error.error = message
      error
    end
    
    def internal_response
      @http.response
    end

    def code
      @http.code
    end

    def to_s
      if success?
        "OK"
      else
        "ERROR: #{error}"
      end
    end

    private

    def error_message_from_response
      return if success?
      return if @http.nil?
      @http.body
    end
  end
end
