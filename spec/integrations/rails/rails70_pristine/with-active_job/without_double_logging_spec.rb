# frozen_string_literal: true

# Karafka with Rails should not log twice to stdout

# @see https://github.com/karafka/karafka/issues/1155

ENV['KARAFKA_CLI'] = 'true'

require 'stringio'

strio = StringIO.new

proper_stdout = $stdout
proper_stderr = $stderr

$stdout = strio
$stderr = strio

require 'active_support/core_ext/integer/time'

class CustomFormatter < ::Logger::Formatter
  def call(severity, timestamp, _, input)
    msg = input.is_a?(String) ? input : input.inspect

    "[CustomFormatter] [#{format_datetime(timestamp)}] #{severity} -- #{msg}\n"
  end
end

Bundler.require(:default)

require 'tempfile'

class ExampleApp < Rails::Application
  config.eager_load = 'test'
end

logger = ActiveSupport::Logger.new($stdout)
logger.formatter = CustomFormatter.new

Rails.configuration.logger = logger

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV['KARAFKA_BOOT_FILE'] = dummy_boot_file

ExampleApp.initialize!

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

$stdout = proper_stdout
$stderr = proper_stderr

assert_equal 2, strio.string.split('Running Karafka').size, strio.string
