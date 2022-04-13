# frozen_string_literal: true

# Karafka should work fine with Rails 6 even when it is just a transitive dependency and is not
# in active use. In case like this KARAFKA_BOOT_FILE needs to be set to "false"
#
# @see https://github.com/karafka/karafka/issues/813

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

assert_equal true, disabled
