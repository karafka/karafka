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

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'

  spec.add_dependency 'activesupport'
  spec.add_dependency 'aspector'
  spec.add_dependency 'celluloid'
  spec.add_dependency 'poseidon'
  spec.add_dependency 'poseidon_cluster'
  spec.add_dependency 'sidekiq'
  spec.add_dependency 'sidekiq-glass'
  spec.add_dependency 'envlogic'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec)/}) }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = %w( lib )
end
