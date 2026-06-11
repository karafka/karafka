# frozen_string_literal: true

require "karafka"
require "securerandom"

# The spec name is embedded in the topic name directly, so any broker-side log entry or
# warning mentioning this topic is traceable to this spec by a plain grep - no hashing needed
TOPIC = "it-puma_with_worker_poro-#{SecureRandom.hex(6)}".freeze
PID = Process.pid

workers 1
silence_single_worker_warning

preload_app!

class ShutdownConsumer < Karafka::BaseConsumer
  def consume
    ::Process.kill("TERM", PID)
  end
end

Karafka::App.setup do |config|
  config.kafka = { "bootstrap.servers": "127.0.0.1:9092" }
  config.client_id = SecureRandom.hex(6)
end

Karafka::App.routes.draw do
  topic TOPIC do
    consumer ShutdownConsumer
  end
end

on_worker_boot do
  # Pre-create the topic so producing and the embedded consumer subscription do not race on
  # broker-side auto-creation (TOPIC_ALREADY_EXISTS broker warnings)
  Karafka::Admin.create_topic(TOPIC, 1, 1)

  Karafka.producer.produce_sync(topic: TOPIC, payload: "bye bye")

  Karafka::Embedded.start
end

on_worker_shutdown do
  Karafka::Embedded.stop
end
