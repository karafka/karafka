lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rake'
require 'karafka/version'

Gem::Specification.new do |spec|
  spec.name          = 'karafka'
  spec.version       = ::Karafka::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ['Maciej Mensfeld', 'Pavlo Vavruk']
  spec.email         = %w( maciej@mensfeld.pl pavlo.vavruk@gmail.com )
  spec.homepage      = 'https://github.com/karafka/karafka'
  spec.summary       = %q{ Ruby based Microframework for handling Apache Kafka incomig messages }
  spec.description   = %q{ Microframework used to simplify Kafka based Ruby applications }
  spec.license       = 'MIT'

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.4'

  spec.add_dependency 'activesupport', '~> 4.2'
  spec.add_dependency 'poseidon'
  spec.add_dependency 'poseidon_cluster'
  spec.add_dependency 'sidekiq', '~> 4.0'
  spec.add_dependency 'worker-glass', '~> 0.2'
  spec.add_dependency 'celluloid', '~> 0.17'
  spec.add_dependency 'envlogic', '~> 1.0'
  spec.add_dependency 'sinatra', '~> 1.4'
  spec.add_dependency 'puma', '~> 2.15'
  spec.add_dependency 'waterdrop', '~> 0.1'
  spec.add_dependency 'thor', '~> 0.19'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec)/}) }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = %w( lib )
end
