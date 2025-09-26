# -*- encoding: utf-8 -*-
require File.expand_path('../lib/reel/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Tony Arcieri"]
  gem.email         = ["tony.arcieri@gmail.com"]
  gem.description   = "A Celluloid::IO-powered HTTP server"
  gem.summary       = "A Reel good HTTP server"
  gem.homepage      = "https://github.com/celluloid/reel"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "reel"
  gem.require_paths = ["lib"]
  gem.version       = Reel::VERSION

  gem.required_ruby_version = '>= 3.3.0'

  gem.add_runtime_dependency 'celluloid',        '>= 0.15.1'
  gem.add_runtime_dependency 'celluloid-io',     '>= 0.15.0'
  gem.add_runtime_dependency 'celluloid-fsm',    '>= 0.20.0'
  gem.add_runtime_dependency 'http',             '>= 0.6.0'
  gem.add_runtime_dependency 'websocket-driver', '>= 0.5.1'

  gem.add_development_dependency 'rake', '>= 12.0'
  gem.add_development_dependency 'rspec', '>= 3.0'
  gem.add_development_dependency 'certificate_authority'
  gem.add_development_dependency 'websocket_parser', '>= 0.1.6'
end
