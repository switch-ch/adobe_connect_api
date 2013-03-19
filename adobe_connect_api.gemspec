# -*- encoding: utf-8 -*-
require File.expand_path('../lib/adobe_connect_api/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Christian Rohrer"]
  gem.email         = ["christian.rohrer@switch.ch"]
  gem.description   = %q{Wrapper to the Adobe Connect API}
  gem.summary       = %q{Wrapper to the Adobe Connect API written in Ruby}
  gem.homepage      = ""

  gem.add_dependency "xml-simple"
  gem.add_development_dependency "rspec"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "adobe_connect_api"
  gem.require_paths = ["lib"]
  gem.version       = AdobeConnectApi::VERSION
end
