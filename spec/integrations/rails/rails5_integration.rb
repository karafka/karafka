# frozen_string_literal: true

# Karafka should work with Rails 5 using the default setup

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'rails', '5.2.6.2'
  gem 'karafka', path: karafka_gem_root
end

require 'rails'
require 'karafka'

class ExampleApp < Rails::Application
  config.eager_load = 'test'
end

Rails.configuration.middleware.delete ActionDispatch::Static

DUMMY_BOOT_FILE = "#{Tempfile.new.path}.rb"
FileUtils.touch(DUMMY_BOOT_FILE)

ENV['KARAFKA_BOOT_FILE'] = DUMMY_BOOT_FILE

ExampleApp.initialize!

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector.data[0] << true
  end
end

draw_routes(Consumer)
produce(DataCollector.topic, '1')

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 1
end

assert_equal 1, DataCollector.data.size
assert_equal '5.2.6.2', Rails.version
