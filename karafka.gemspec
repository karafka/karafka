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
  spec.licenses    = %w[LGPL-3.0-only Commercial]
  spec.summary     = 'Karafka is Ruby and Rails efficient Kafka processing framework.'
  spec.description = <<-DESC
    Karafka is Ruby and Rails efficient Kafka processing framework.

    Karafka allows you to capture everything that happens in your systems in large scale,
    without having to focus on things that are not your business domain.
  DESC

  spec.add_dependency 'base64', '~> 0.2'
  spec.add_dependency 'karafka-core', '>= 2.5.2', '< 2.6.0'
  spec.add_dependency 'karafka-rdkafka', '>= 0.19.5'
  spec.add_dependency 'waterdrop', '>= 2.8.3', '< 3.0.0'
  spec.add_dependency 'zeitwerk', '~> 2.3'

  spec.required_ruby_version = '>= 3.0.0'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec)/}) }
  spec.executables   = %w[karafka]
  spec.require_paths = %w[lib]

  spec.metadata = {
    'funding_uri' => 'https://karafka.io/#become-pro',
    'homepage_uri' => 'https://karafka.io',
    'changelog_uri' => 'https://karafka.io/docs/Changelog-Karafka',
    'bug_tracker_uri' => 'https://github.com/karafka/karafka/issues',
    'source_code_uri' => 'https://github.com/karafka/karafka',
    'documentation_uri' => 'https://karafka.io/docs',
    'rubygems_mfa_required' => 'true'
  }
end
