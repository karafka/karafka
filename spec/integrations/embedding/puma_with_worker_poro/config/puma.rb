# frozen_string_literal: true

require 'karafka'
require 'securerandom'

TOPIC = SecureRandom.hex(6)
PID = Process.pid

workers 1
silence_single_worker_warning

preload_app!

class ShutdownConsumer < Karafka::BaseConsumer
  def consume
    ::Process.kill('TERM', PID)
  end
end

::Karafka::App.setup do |config|
  config.kafka = { 'bootstrap.servers': '127.0.0.1:9092' }
  config.client_id = SecureRandom.hex(6)
end

::Karafka.producer.produce_sync(topic: TOPIC, payload: 'bye bye')

::Karafka::App.routes.draw do
  topic TOPIC do
    consumer ShutdownConsumer
  end
end

on_worker_boot do
  ::Karafka::Embedded.start
end

on_worker_shutdown do
  ::Karafka::Embedded.stop
end
