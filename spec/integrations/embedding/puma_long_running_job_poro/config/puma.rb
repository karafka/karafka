# frozen_string_literal: true

# Simulates the "ugly" scenario:
# A single Kafka message fans out into a large batch of work (like parsing a 400k-entry parquet
# log drop). The processing takes so long that when Puma decides to shut down, the worker cannot
# finish in time and Puma master sends SIGKILL.
#
# In this test we simulate a consumer that takes a very long time processing (sleep) without
# checking Karafka::App.stopping?. Puma's worker_shutdown_timeout is set low so the master
# will SIGKILL the worker before processing completes.
#
# Expected outcome: Puma master kills the worker with SIGKILL because Embedded.stop blocks
# longer than worker_shutdown_timeout allows.

require "karafka"
require "securerandom"
require "digest"

# Topic prefix follows the suite-wide it-<hash>- convention. The hash is computed from this
# spec's path given as a literal (not from runtime state), so it is environment-independent,
# unique per spec and discoverable via bin/tests_topics_hashes
SPEC_HASH = Digest::MD5.hexdigest(
  "spec/integrations/embedding/puma_long_running_job_poro/flow_spec.rb"
)[0, 6]
TOPIC = "it-#{SPEC_HASH}-#{SecureRandom.hex(6)}".freeze
PID = Process.pid
RESULT_FILE = File.join(__dir__, "..", "result.txt")
SHUTDOWN_FILE = File.join(__dir__, "..", "shutdown.txt")

workers 1
silence_single_worker_warning

preload_app!

# worker_shutdown_timeout controls how long Puma master waits for a worker to exit during
# shutdown before sending SIGKILL. Set it very short to simulate the real-world scenario
# where processing time (200+s) far exceeds the allowed shutdown window.
worker_shutdown_timeout 5

class LongRunningConsumer < Karafka::BaseConsumer
  def consume
    File.write(RESULT_FILE, "consume_started")

    messages.each do |_message|
      # Simulate processing a huge log drop: fan out into many batches without checking
      # Karafka::App.stopping? — this is the problematic pattern.
      # In reality this would be downloading + parsing a parquet file with 400k entries,
      # deduplicating via Redis, and producing to another topic in batches.
      50.times do
        # Each "batch" takes some time — total exceeds Puma's worker_shutdown_timeout
        sleep 1
        # Simulate producing a batch of events to Kafka
        # (In the real scenario: Karafka.producer.produce_many_sync(batch))
      end
    end

    # This line is never reached because Puma kills us first
    File.write(RESULT_FILE, "consume_finished")
  end
end

Karafka::App.setup do |config|
  config.kafka = { "bootstrap.servers": "127.0.0.1:9092" }
  config.client_id = SecureRandom.hex(6)
  # Give Karafka plenty of time — but Puma won't wait that long
  config.shutdown_timeout = 120_000
end

Karafka::App.routes.draw do
  topic TOPIC do
    consumer LongRunningConsumer
  end
end

on_worker_boot do
  # Pre-create the topic so producing and the embedded consumer subscription do not race on
  # broker-side auto-creation (TOPIC_ALREADY_EXISTS broker warnings)
  Karafka::Admin.create_topic(TOPIC, 1, 1)

  # Produce a message that will trigger the long-running consumer
  Karafka.producer.produce_sync(topic: TOPIC, payload: "big-log-drop-s3-event")

  Karafka::Embedded.start
end

on_worker_shutdown do
  # This hook calls Embedded.stop which is BLOCKING — it waits until Karafka::App.terminated?
  # Because the consumer is stuck in a long sleep loop, Karafka can't terminate quickly.
  # Puma master's worker_shutdown_timeout fires and sends SIGKILL to this worker process.
  File.write(SHUTDOWN_FILE, "shutdown_hook_started:#{Time.now.to_f}")
  Karafka::Embedded.stop
  # This line is never reached — worker is SIGKILL'd before Embedded.stop returns
  File.write(SHUTDOWN_FILE, "shutdown_hook_finished:#{Time.now.to_f}")
end

# Trigger Puma shutdown after the consumer has started processing
on_booted do
  Thread.new do
    # Wait until the consumer actually starts processing (writes result file)
    sleep 0.5 until File.exist?(RESULT_FILE)
    # Give it a moment to be well into the long processing loop
    sleep 2
    Process.kill("TERM", PID)
  end
end
