# frozen_string_literal: true

# Karafka should injected extended ActiveJob routing when ActiveJob is available

# Load all the Railtie stuff like when `rails server`
ENV['KARAFKA_CLI'] = 'true'

Bundler.require(:default)

require 'action_controller'
require 'tempfile'

class ExampleApp < Rails::Application
  config.eager_load = 'test'
end

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV['KARAFKA_BOOT_FILE'] = dummy_boot_file

ExampleApp.initialize!

setup_karafka

draw_routes Class.new do
  active_job_topic DT.topic
end
