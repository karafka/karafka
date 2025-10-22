# frozen_string_literal: true

require 'karafka'
require 'securerandom'

TOPIC = "it-#{SecureRandom.hex(6)}".freeze
PID = Process.pid

preload_app!

workers 0
threads 1, 1

class ShutdownConsumer < Karafka::BaseConsumer
  def consume; end
end

Karafka::App.setup do |config|
  config.kafka = { 'bootstrap.servers': '127.0.0.1:9092' }
  config.client_id = SecureRandom.hex(6)
end

Karafka::App.routes.draw do
  topic TOPIC do
    consumer ShutdownConsumer
  end
end

on_booted do
  Karafka::Embedded.start
  sleep(1)
  Process.kill('TERM', PID)
end

# There is no `on_worker_shutdown` equivalent for single mode
on_stopped do
  Karafka::Embedded.stop
end
