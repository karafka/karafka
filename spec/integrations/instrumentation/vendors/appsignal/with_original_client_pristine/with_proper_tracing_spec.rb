# frozen_string_literal: true

# This spec ensures, we do not use by accident ActiveSupport methods when working with listeners
# @see https://github.com/karafka/karafka/pull/1624

Bundler.require(:default)

require 'tempfile'
require 'appsignal'

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV['KARAFKA_BOOT_FILE'] = dummy_boot_file

Appsignal.configure do |config|
  config.send_params = false
  config.enable_host_metrics = false
end

Appsignal.start

setup_karafka

require 'karafka/instrumentation/vendors/appsignal/errors_listener'
require 'karafka/instrumentation/vendors/appsignal/metrics_listener'

appsignal_metrics_listener = ::Karafka::Instrumentation::Vendors::Appsignal::MetricsListener.new
Karafka.monitor.subscribe(appsignal_metrics_listener)

appsignal_errors_listener = ::Karafka::Instrumentation::Vendors::Appsignal::ErrorsListener.new
Karafka.monitor.subscribe(appsignal_errors_listener)
Karafka.producer.monitor.subscribe(appsignal_errors_listener)

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
