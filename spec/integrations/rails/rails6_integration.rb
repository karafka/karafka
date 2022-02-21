# frozen_string_literal: true

# Karafka should work with Rails 6 using the default setup

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'rails', '6.1.4.6'
  gem 'karafka', path: gemified_karafka_root
end

require 'rails'
require 'karafka'

class ExampleApp < Rails::Application
  config.eager_load = 'test'
end

Rails.configuration.middleware.delete ActionDispatch::Static

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV['KARAFKA_BOOT_FILE'] = dummy_boot_file

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
assert_equal '6.1.4.6', Rails.version
