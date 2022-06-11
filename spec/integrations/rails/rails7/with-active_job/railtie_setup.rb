# frozen_string_literal: true

# Karafka should work with Rails 7 using the default setup

Bundler.require(:default)

require 'tempfile'

class ExampleApp < Rails::Application
  config.eager_load = 'test'
end

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV['KARAFKA_BOOT_FILE'] = dummy_boot_file

ExampleApp.initialize!

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector[0] << true
  end
end

draw_routes(Consumer)
produce(DataCollector.topic, '1')

start_karafka_and_wait_until do
  DataCollector[0].size >= 1
end

assert_equal 1, DataCollector.data.size
assert_equal '7.0.2.2', Rails.version
