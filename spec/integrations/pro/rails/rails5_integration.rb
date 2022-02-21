# frozen_string_literal: true

# Karafka+Pro should work with Rails 5 using the default setup

gem_root = File.expand_path(File.join(__dir__, '../../../../'))

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'rails', '5.2.6.2'
  gem 'karafka', path: gem_root
end

require 'rails'
require 'karafka'

class ExampleApp < Rails::Application
  config.eager_load = 'test'
end

Rails.configuration.middleware.delete ActionDispatch::Static

DUMMY_BOOT_FILE = Tempfile.new.path + '.rb'
FileUtils.touch(DUMMY_BOOT_FILE)

ENV['KARAFKA_BOOT_FILE'] = DUMMY_BOOT_FILE

ExampleApp.initialize!

setup_karafka do |config|
  config.license.token = pro_license_token
end

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
