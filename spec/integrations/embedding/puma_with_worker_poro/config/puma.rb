# frozen_string_literal: true

require "karafka"
require "securerandom"
require "digest"

# Relativize against the gem root (exported by bin/integrations as KARAFKA_GEM_DIR) so the
# hash matches DataCollector::SPEC_HASH semantics: stable across environments (CI vs local
# absolute paths) and discoverable via bin/tests_topics_hashes
SPEC_HASH = begin
  spec_path = ENV.fetch("KARAFKA_SPEC_PATH", $PROGRAM_NAME)
  gem_dir = ENV["KARAFKA_GEM_DIR"]
  spec_path = spec_path.sub("#{gem_dir}/", "") if gem_dir
  Digest::MD5.hexdigest(spec_path)[0, 6]
end
TOPIC = "it-#{SPEC_HASH}-#{SecureRandom.hex(6)}".freeze
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
  Karafka.producer.produce_sync(topic: TOPIC, payload: "bye bye")

  Karafka::Embedded.start
end

on_worker_shutdown do
  Karafka::Embedded.stop
end
