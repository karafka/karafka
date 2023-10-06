# frozen_string_literal: true

# Karafka should work fine when someone has root level components named based on the features
#
# @see https://github.com/karafka/karafka/issues/1144

# Load all the Railtie stuff like when `rails server`
ENV['KARAFKA_CLI'] = 'true'

class Builder
end

class Topic
end

class Contract
end

Bundler.require(:default)

ENV['RAILS_ENV'] = 'test'

Bundler.require(:default)

class ExampleApp < Rails::Application
  config.eager_load = 'test'
end

ENV['KARAFKA_BOOT_FILE'] = 'false'

disabled = true

begin
  ExampleApp.initialize!
rescue Karafka::Errors::MissingBootFileError
  disabled = false
end

assert disabled
