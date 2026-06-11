# frozen_string_literal: true

require "karafka"
require "securerandom"

# The spec name is embedded in the topic name directly, so any broker-side log entry or
# warning mentioning this topic is traceable to this spec by a plain grep - no hashing needed
TOPIC = "it-puma_single_poro-#{SecureRandom.hex(6)}".freeze
PID = Process.pid

preload_app!

workers 0
threads 1, 1

class ShutdownConsumer < Karafka::BaseConsumer
  def consume
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

on_booted do
  # Pre-create the topic so the consumer subscription does not trigger racing broker-side
  # auto-creation (TOPIC_ALREADY_EXISTS broker warnings)
  Karafka::Admin.create_topic(TOPIC, 1, 1)

  Karafka::Embedded.start
  sleep(1)
  Process.kill("TERM", PID)
end

# There is no `on_worker_shutdown` equivalent for single mode
on_stopped do
  Karafka::Embedded.stop
end
