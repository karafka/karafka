# frozen_string_literal: true

# Reproduces: https://github.com/karafka/waterdrop/issues/866
#
# Puma's `after_stopped` DSL hook in single mode is called from a Ruby signal trap context.
# Ruby forbids Mutex#synchronize from trap contexts and raises:
#   ThreadError: can't be called from trap context
#
# WaterDrop::Producer#close calls Mutex#synchronize, so it raised ThreadError when invoked
# directly from after_stopped. The fix detects the trap context and delegates to a background
# thread automatically.

require "waterdrop"

PID = Process.pid
RESULT_FILE = File.join(__dir__, "..", "result.txt")

# Single mode: no workers, one thread
workers 0
threads 1, 1

PRODUCER = WaterDrop::Producer.new do |config|
  # No real Kafka needed — the ThreadError occurs before any network activity
  config.kafka = { "bootstrap.servers": "127.0.0.1:9092" }
  config.logger = Logger.new(IO::NULL)
end

# This is the hook from the docs for Puma single mode. In Puma 7.x it runs in a
# signal trap context, so calling Mutex#synchronize raises ThreadError unless waterdrop
# detects and escapes the trap context automatically.
after_stopped do
  begin
    PRODUCER.close
    File.write(RESULT_FILE, "success")
  rescue ThreadError => e
    File.write(RESULT_FILE, "thread_error:#{e.message}")
  rescue => e
    File.write(RESULT_FILE, "error:#{e.class}:#{e.message}")
  end
end

on_booted do
  Thread.new do
    sleep 0.5
    Process.kill("TERM", PID)
  end
end
