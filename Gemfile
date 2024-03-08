# frozen_string_literal: true

source 'https://rubygems.org'

plugin 'diffend'

gemspec

# Karafka gem does not require activejob nor karafka-web to work
# They are added here because they are part of the integration suite
# Since some of those are only needed for some specs, they should never be required automatically
group :integrations do
  %w[
    activejob
    karafka-testing
    karafka-web
    rspec
  ].each do |gem_name|
    gem gem_name, require: false
  end
end

group :test do
  gem 'byebug'
  gem 'factory_bot'
  gem 'rspec'
  gem 'simplecov'
end
