# frozen_string_literal: true

source 'https://rubygems.org'

plugin 'diffend'

gemspec

# Karafka gem does not require activejob, karafka-web or fugit to work
# They are added here because they are part of the integration suite
# Since some of those are only needed for some specs, they should never be required automatically
group :integrations, :test do
  gem 'fugit', require: false
  gem 'rspec', require: false
  gem 'stringio'
end

group :integrations do
  gem 'activejob', require: false
  gem 'karafka-testing', '>= 2.4.6', require: false
  gem 'karafka-web', '>= 0.10.0.rc2', require: false
end

group :test do
  gem 'byebug'
  gem 'factory_bot'
  gem 'ostruct'
  gem 'simplecov'
end
