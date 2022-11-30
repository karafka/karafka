# frozen_string_literal: true

# Karafka should fail with a missing boot file error when used within railtie

# Load all the Railtie stuff like when `rails server`
ENV['KARAFKA_CLI'] = 'true'

Bundler.require(:default)

require 'tempfile'

class ExampleApp < Rails::Application
  config.eager_load = 'test'
end

ENV['KARAFKA_BOOT_FILE'] = 'non-existing'

begin
  ExampleApp.initialize!
  failure = false
rescue Karafka::Errors::MissingBootFileError
  failure = true
end

assert failure
