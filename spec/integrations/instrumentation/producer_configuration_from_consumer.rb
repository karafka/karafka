# frozen_string_literal: true

exit

LOGS = StringIO.new

LOGGER = Logger.new(LOGS)
LOGGER.level = Logger::DEBUG

setup_karafka do |config|
  config.logger = LOGGER
  config.kafka = {
    'bootstrap.servers': '127.0.0.1:9092',
    'request.required.acks': 1
  }
end

draw_routes(Class.new)

Karafka::App.producer

module Rdkafka
  module Bindings

    attach_function :rd_kafka_conf_properties_show, [:pointer], :void
  end
end


require 'tempfile'
require 'fiddle'
Rdkafka::Bindings.rd_kafka_conf_properties_show(Fiddle::Pointer.to_ptr(Tempfile.new).to_i)

start_karafka_and_wait_until do
  true
end

LOGS.rewind

logs = LOGS.read

puts 'a'
puts logs
