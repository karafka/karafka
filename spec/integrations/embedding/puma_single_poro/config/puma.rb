# frozen_string_literal: true

require "karafka"
require "securerandom"
require "digest"

# Topic prefix follows the suite-wide it-<hash>- convention. The hash is computed from this
# spec's path given as a literal (not from runtime state), so it is environment-independent,
# unique per spec and discoverable via bin/tests_topics_hashes
SPEC_HASH = Digest::MD5.hexdigest(
  "spec/integrations/embedding/puma_single_poro/flow_spec.rb"
)[0, 6]
TOPIC = "it-#{SPEC_HASH}-#{SecureRandom.hex(6)}".freeze
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
  Karafka::Admin.create_topic(TOPIC, 1, 1)

  Karafka::Embedded.start
  sleep(1)
  Process.kill("TERM", PID)
end

# There is no `on_worker_shutdown` equivalent for single mode
on_stopped do
  Karafka::Embedded.stop
end
