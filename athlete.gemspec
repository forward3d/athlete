# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'athlete/version'

Gem::Specification.new do |spec|
  spec.name          = "athlete"
  spec.version       = Athlete::VERSION
  spec.authors       = ["Andy Sykes"]
  spec.email         = ["github@tinycat.co.uk"]
  spec.summary       = %q{A deployment tool for Marathon and Mesos}
  spec.description   = %q{A deployment tool for building Docker containers for Marathon and Mesos}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  
  spec.add_dependency "thor"
  spec.add_dependency "httparty"
  spec.add_dependency "multi_json"
end
