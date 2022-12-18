# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'karafka/version'

Gem::Specification.new do |spec|
  spec.name        = 'karafka'
  spec.version     = ::Karafka::VERSION
  spec.platform    = Gem::Platform::RUBY
  spec.authors     = ['Maciej Mensfeld']
  spec.email       = %w[contact@karafka.io]
  spec.homepage    = 'https://karafka.io'
  spec.licenses    = ['LGPL-3.0', 'Commercial']
  spec.summary     = 'Karafka is Ruby and Rails efficient Kafka processing framework.'
  spec.description = <<-DESC
    Karafka is Ruby and Rails efficient Kafka processing framework.

    Karafka allows you to capture everything that happens in your systems in large scale,
    without having to focus on things that are not your business domain.
  DESC

  spec.add_dependency 'karafka-core', '>= 2.0.7', '< 3.0.0'
  spec.add_dependency 'thor', '>= 0.20'
  spec.add_dependency 'waterdrop', '>= 2.4.7', '< 3.0.0'
  spec.add_dependency 'zeitwerk', '~> 2.3'

  spec.required_ruby_version = '>= 2.7.0'

  if $PROGRAM_NAME.end_with?('gem')
    spec.signing_key = File.expand_path('~/.ssh/gem-private_key.pem')
  end

  spec.cert_chain    = %w[certs/cert_chain.pem]
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec)/}) }
  spec.executables   = %w[karafka]
  spec.require_paths = %w[lib]

  spec.metadata = {
    'funding_uri' => 'https://karafka.io/#become-pro',
    'homepage_uri' => 'https://karafka.io',
    'changelog_uri' => 'https://github.com/karafka/karafka/blob/master/CHANGELOG.md',
    'bug_tracker_uri' => 'https://github.com/karafka/karafka/issues',
    'source_code_uri' => 'https://github.com/karafka/karafka',
    'documentation_uri' => 'https://karafka.io/docs',
    'rubygems_mfa_required' => 'true'
  }
end
