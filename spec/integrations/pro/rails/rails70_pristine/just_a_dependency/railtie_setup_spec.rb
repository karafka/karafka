# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka+Pro should work with Rails 7 using the default setup

# Load all the Railtie stuff like when `rails server`
ENV['KARAFKA_CLI'] = 'true'

Bundler.require(:default)

require 'tempfile'

class ExampleApp < Rails::Application
  config.eager_load = 'test'
end

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV['KARAFKA_BOOT_FILE'] = dummy_boot_file

ExampleApp.initialize!

mod = Module.new do
  def self.token
    ENV.fetch('KARAFKA_PRO_LICENSE_TOKEN')
  end
end

Karafka.const_set('License', mod)
require 'karafka/pro/loader'

Karafka::Pro::Loader.require_all

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

draw_routes(Consumer)
produce(DT.topic, '1')

start_karafka_and_wait_until do
  DT.key?(0)
end

assert_equal 1, DT.data.size
assert_equal '7.0.8', Rails.version
assert Karafka.pro?
