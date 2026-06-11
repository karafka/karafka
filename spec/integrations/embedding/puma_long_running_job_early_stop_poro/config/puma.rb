# frozen_string_literal: true

# Simulates the "good" scenario:
# A single Kafka message fans out into a large batch of work, but the consumer checks
# Karafka::App.stopping? between each chunk. When Puma triggers shutdown, Karafka signals
# stopping and the consumer breaks out of its processing loop early. Because the offset is
# NOT committed (mark_as_consumed is never called), a new worker instance will pick up the
# same message and resume processing.
#
# This pattern allows Puma workers to shut down gracefully within the worker_shutdown_timeout,
# avoiding SIGKILL from the Puma master.
#
# Expected outcome: clean shutdown, exit via SIGTERM (15), no SIGKILL.

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
RESULT_FILE = File.join(__dir__, "..", "result.txt")
SHUTDOWN_FILE = File.join(__dir__, "..", "shutdown.txt")

workers 1
silence_single_worker_warning

# Same short worker_shutdown_timeout as the ugly scenario
worker_shutdown_timeout 5

preload_app!

class EarlyStopConsumer < Karafka::BaseConsumer
  def consume
    message = messages.first

    File.write(RESULT_FILE, "consume_started")

    # Simulate processing a large log drop in chunks (like each_slice(1_000) on 400k records).
    # Between each chunk, we check if Karafka is shutting down.
    batches_processed = 0

    50.times do
      # Check if Karafka is shutting down — this is the key fix!
      # When Puma triggers shutdown → on_worker_shutdown → Karafka::Embedded.stop →
      # Karafka::App.stopping? becomes true
      if Karafka::App.stopping?
        File.write(RESULT_FILE, "early_exit:#{batches_processed}")
        # Break out early. Because we never call mark_as_consumed(message),
        # the offset is not committed. A new worker will pick this message up.
        return
      end

      # Simulate processing a batch of ~1000 log entries
      sleep 0.5
      batches_processed += 1

      # In the real scenario, each iteration would:
      # 1. DedupLogs.call!(slice) — deduplicate this chunk
      # 2. Karafka.producer.produce_many_async(events) — dispatch to output topic
    end

    # Only commit offset after ALL batches are processed successfully
    mark_as_consumed(message)
    File.write(RESULT_FILE, "consume_finished:#{batches_processed}")
  end
end

Karafka::App.setup do |config|
  config.kafka = { "bootstrap.servers": "127.0.0.1:9092" }
  config.client_id = SecureRandom.hex(6)
  config.shutdown_timeout = 60_000
end

Karafka::App.routes.draw do
  topic TOPIC do
    consumer EarlyStopConsumer
  end
end

on_worker_boot do
  Karafka.producer.produce_sync(topic: TOPIC, payload: "big-log-drop-s3-event")

  Karafka::Embedded.start
end

on_worker_shutdown do
  # Now Embedded.stop will resolve quickly because the consumer checks stopping? and returns
  # early, allowing Karafka to complete its shutdown within Puma's worker_shutdown_timeout.
  File.write(SHUTDOWN_FILE, "shutdown_hook_started:#{Time.now.to_f}")
  Karafka::Embedded.stop
  File.write(SHUTDOWN_FILE, "shutdown_hook_finished:#{Time.now.to_f}")
end

# Trigger Puma shutdown after the consumer has started processing
on_booted do
  Thread.new do
    # Wait until the consumer actually starts processing (writes result file)
    sleep 0.5 until File.exist?(RESULT_FILE)
    # Give it a moment to process a few batches
    sleep 2
    Process.kill("TERM", PID)
  end
end
