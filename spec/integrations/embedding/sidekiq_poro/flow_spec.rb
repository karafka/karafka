# frozen_string_literal: true

# Test that Karafka can run embedded in Sidekiq without Redis
# This test does not cover all the cases because it uses the Sidekiq testing mode, but at least
# it ensures that we don't have any immediate crashing conflicts.

require "bundler/setup"
require "sidekiq"
require "sidekiq/testing"
require "karafka"
require "digest"

class Accu
  class << self
    def fetch
      @fetch ||= {}
    end
  end
end

# Enable fake mode to avoid Redis dependency
Sidekiq::Testing.fake!

SPEC_HASH = Digest::MD5.hexdigest($PROGRAM_NAME)[0, 6]
TOPIC = "it-#{SPEC_HASH}-#{SecureRandom.hex(6)}".freeze
PID = Process.pid

# Define an in-memory worker class
class TestWorker
  include Sidekiq::Worker

  def perform
    Accu.fetch[:sidekiq] = true
  end
end

class TestConsumer < Karafka::BaseConsumer
  def consume
    Accu.fetch[:karafka] = true
  end
end

Karafka::App.setup do |config|
  config.kafka = { "bootstrap.servers": "127.0.0.1:9092" }
  config.client_id = SecureRandom.hex(6)
end

Karafka::App.routes.draw do
  topic TOPIC do
    consumer TestConsumer
  end
end

Karafka::Admin.create_topic(TOPIC, 1, 1)
Karafka.producer.produce_sync(topic: TOPIC, payload: "")

Karafka::Embedded.start
TestWorker.perform_async

Sidekiq::Worker.drain_all

sleep(0.1) until Accu.fetch.size >= 2

Karafka::Embedded.stop
