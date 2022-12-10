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
    # Stop is blocking, so we want to avoid a dead-lock here
    # Normally you would add it to `on_worker_shutdown`
    Thread.new { ::Karafka::Embedded.stop }
  end

  def shutdown
    ::Process.kill('TERM', PID)
  end
end

on_worker_boot do
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

  ::Karafka::Embedded.start
end
