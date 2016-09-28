lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'karafka/version'

Gem::Specification.new do |spec|
  spec.name          = 'karafka'
  spec.version       = ::Karafka::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ['Maciej Mensfeld', 'Pavlo Vavruk']
  spec.email         = %w( maciej@mensfeld.pl pavlo.vavruk@gmail.com )
  spec.homepage      = 'https://github.com/karafka/karafka'
  spec.summary       = %q{ Ruby based Microframework for handling Apache Kafka incoming messages }
  spec.description   = %q{ Microframework used to simplify Kafka based Ruby applications }
  spec.license       = 'MIT'

  spec.add_development_dependency 'bundler'

  spec.add_dependency 'ruby-kafka', '= 0.3.15'
  spec.add_dependency 'sidekiq'
  spec.add_dependency 'worker-glass'
  spec.add_dependency 'celluloid', '>= 0.17'
  spec.add_dependency 'envlogic'
  spec.add_dependency 'waterdrop'
  spec.add_dependency 'rake'
  spec.add_dependency 'thor'
  spec.add_dependency 'activesupport'
  spec.add_dependency 'dry-configurable'
  spec.required_ruby_version = '>= 2.3.0'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec)/}) }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = %w( lib )
end
