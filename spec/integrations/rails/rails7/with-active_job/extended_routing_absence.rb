# frozen_string_literal: true

# Karafka should injected extended ActiveJob routing when ActiveJob is available

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

draw_routes Class.new do
  active_job_topic 'test'
end
