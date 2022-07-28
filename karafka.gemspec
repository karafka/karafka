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
  spec.homepage    = 'https://karafka.io'
  spec.summary     = 'Efficient Kafka processing framework for Ruby and Rails'
  spec.description = 'Framework used to simplify Apache Kafka based Ruby applications development'
  spec.licenses    = ['LGPL-3.0', 'Commercial']

  spec.add_dependency 'karafka-core', '>= 2.0.0', '< 3.0.0'
  spec.add_dependency 'rdkafka', '>= 0.10'
  spec.add_dependency 'thor', '>= 0.20'
  spec.add_dependency 'waterdrop', '>= 2.4.0', '< 3.0.0'
  spec.add_dependency 'zeitwerk', '~> 2.3'

  spec.required_ruby_version = '>= 2.7.0'

  if $PROGRAM_NAME.end_with?('gem')
    spec.signing_key = File.expand_path('~/.ssh/gem-private_key.pem')
  end

  spec.cert_chain    = %w[certs/mensfeld.pem]
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec)/}) }
  spec.executables   = %w[karafka]
  spec.require_paths = %w[lib]

  spec.metadata = {
    'source_code_uri' => 'https://github.com/karafka/karafka',
    'rubygems_mfa_required' => 'true'
  }
end
