# frozen_string_literal: true

require 'karafka'
require 'securerandom'
require_relative '../../../support/kafka_helper'

TOPIC = "it-#{SecureRandom.hex(6)}".freeze
PID = Process.pid

preload_app!

workers 0
threads 1, 1

class ShutdownConsumer < Karafka::BaseConsumer
  def consume; end
end

::Karafka::App.setup do |config|
  config.kafka = { 'bootstrap.servers': kafka_bootstrap_servers }
  config.client_id = SecureRandom.hex(6)
end

::Karafka::App.routes.draw do
  topic TOPIC do
    consumer ShutdownConsumer
  end
end

@config.options[:events].on_booted do
  ::Karafka::Embedded.start
  sleep(1)
  ::Process.kill('TERM', PID)
end

# There is no `on_worker_shutdown` equivalent for single mode
@config.options[:events].on_stopped do
  ::Karafka::Embedded.stop
end
