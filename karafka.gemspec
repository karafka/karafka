# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'karafka/version'

Gem::Specification.new do |spec|
  spec.name        = 'karafka'
  spec.version     = ::Karafka::VERSION
  spec.platform    = Gem::Platform::RUBY
  spec.authors     = ['Maciej Mensfeld', 'Pavlo Vavruk', 'Adam Gwozdowski']
  spec.email       = %w[maciej@coditsu.io pavlo.vavruk@gmail.com adam99g@gmail.com]
  spec.homepage    = 'https://github.com/karafka/karafka'
  spec.summary     = 'Ruby based framework for working with Apache Kafka'
  spec.description = 'Framework used to simplify Apache Kafka based Ruby applications development'
  spec.license     = 'MIT'

  spec.add_dependency 'activesupport', '>= 4.0'
  spec.add_dependency 'dry-configurable', '~> 0.7'
  spec.add_dependency 'dry-inflector', '~> 0.1'
  spec.add_dependency 'dry-monitor', '~> 0.1'
  spec.add_dependency 'dry-validation', '~> 0.11'
  spec.add_dependency 'envlogic', '~> 1.0'
  spec.add_dependency 'multi_json', '>= 1.12'
  spec.add_dependency 'rake', '>= 11.3'
  spec.add_dependency 'require_all', '>= 1.4'
  spec.add_dependency 'ruby-kafka', '>= 0.6'
  spec.add_dependency 'thor', '~> 0.19'
  spec.add_dependency 'waterdrop', '~> 1.2.4'

  spec.post_install_message = <<~MSG
    \e[93mWarning:\e[0m If you're using Kafka 0.10, please lock ruby-kafka in your Gemfile to version '0.6.8':
    gem 'ruby-kafka', '~> 0.6.8'
  MSG

  spec.required_ruby_version = '>= 2.3.0'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec)/}) }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = %w[lib]
end
