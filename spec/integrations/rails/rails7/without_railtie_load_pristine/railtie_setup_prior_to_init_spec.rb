# frozen_string_literal: true

# When we disable Railtie load, it should not be included and should not automatically integrate
# with Ruby on Rails. This can be used by advanced users to setup things the way they want,
# without auto-integration.

ENV['KARAFKA_RAILTIE_LOAD'] = 'false'

# We should be able to load Karafka even when Rails are not yet initialized
require 'karafka'
require 'tempfile'

assert_equal true, Object.const_defined?(:Karafka)

# No Rails here expected
assert_equal false, Object.const_defined?(:Rails)

Bundler.require(:default)

class ExampleApp < Rails::Application
  config.eager_load = 'test'
end

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV['KARAFKA_BOOT_FILE'] = dummy_boot_file

# Here the consumer auto load paths should not be visible because they are configured via railtie
# that we have disabled
assert_equal [], ExampleApp.config.autoload_paths

require 'karafka/railtie'

ExampleApp.initialize!

# Once tha app is initialized and the Railtie was loaded prior, this should be visible
assert_equal %w[app/consumers], ExampleApp.config.autoload_paths

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

draw_routes(Consumer)
produce(DT.topic, '1')

start_karafka_and_wait_until do
  DT[0].size >= 1
end

assert_equal 1, DT.data.size
assert_equal '7.0.4', Rails.version
