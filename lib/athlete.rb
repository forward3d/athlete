require 'logger'
require 'open3'
require 'httparty'
require 'multi_json'
require_relative 'marathon/client'
require_relative 'marathon/response'

require_relative "athlete/version"
require_relative "athlete/logging"
require_relative "athlete/utils"
require_relative "athlete/build"
require_relative "athlete/cli"
require_relative "athlete/deployment"

module Athlete
  class BuildConfigurationInvalid < Exception; end
  class BuildFailedException < Exception; end
  class CommandExecutionFailed < Exception; end
  class ConfigurationInvalidException < Exception; end
end
