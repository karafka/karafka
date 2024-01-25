# frozen_string_literal: true

source 'https://rubygems.org'

plugin 'diffend'

gemspec

# Karafka gem does not require activejob nor karafka-web  to work
# They are added here because they are part of the integration suite
group :integrations do
  gem 'activejob'
  gem 'karafka-web', '>= 0.8.0.rc1'
end

group :test do
  gem 'byebug'
  gem 'factory_bot'
  gem 'rspec'
  gem 'simplecov'
end
