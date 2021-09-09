# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'karafka/version'

Gem::Specification.new do |spec|
  spec.name        = 'karafka'
  spec.version     = ::Karafka::VERSION
  spec.platform    = Gem::Platform::RUBY
  spec.authors     = ['Maciej Mensfeld']
  spec.email       = %w[maciej@mensfeld.pl]
  spec.homepage    = 'https://github.com/karafka/karafka'
  spec.summary     = 'Ruby based framework for working with Apache Kafka'
  spec.description = 'Framework used to simplify Apache Kafka based Ruby applications development'
  spec.license     = 'LGPL-3.0'

  spec.add_dependency 'dry-configurable', '~> 0.8'
  spec.add_dependency 'dry-monitor', '~> 0.3'
  spec.add_dependency 'dry-validation', '~> 1.2'
  spec.add_dependency 'irb', '~> 1.0'
  spec.add_dependency 'rdkafka', '>= 0.9.0'
  spec.add_dependency 'thor', '>= 0.20'
  spec.add_dependency 'waterdrop', '~> 2.0'
  spec.add_dependency 'zeitwerk', '~> 2.1'

  spec.required_ruby_version = '>= 2.6.0'

  if $PROGRAM_NAME.end_with?('gem')
    spec.signing_key = File.expand_path('~/.ssh/gem-private_key.pem')
  end

  spec.cert_chain    = %w[certs/mensfeld.pem]
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec)/}) }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = %w[lib]
end
