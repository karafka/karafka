# frozen_string_literal: true

source 'https://rubygems.org'

plugin 'diffend'

gemspec

# Karafka gem does not require this but we add it here so we can test the integration with
# ActiveJob much easier
group :integrations do
  gem 'activejob'
end

group :test do
  gem 'byebug'
  gem 'factory_bot'
  gem 'rspec'
  gem 'simplecov'
end
