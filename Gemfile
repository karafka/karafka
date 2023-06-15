# frozen_string_literal: true

source 'https://rubygems.org'

plugin 'diffend'

gemspec

gem 'waterdrop', path: '/mnt/software/Karafka/waterdrop'
gem 'karafka-core', path: '/mnt/software/Karafka/karafka-core'

# Karafka gem does not require activejob nor karafka-web  to work
# They are added here because they are part of the integration suite
group :integrations do
  gem 'activejob'
  gem 'karafka-web'
end

group :test do
  gem 'byebug'
  gem 'factory_bot'
  gem 'rspec'
  gem 'simplecov'
end
