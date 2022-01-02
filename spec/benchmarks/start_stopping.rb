# frozen_string_literal: true

# A simple case where we measure how long does it take to start and stop Karafka several times
# This serves as a baseline to determine if we can reboot the server in process for the development
# setup when using with code-reload.

setup_karafka

100.times do
  Karafka.producer.buffer(topic: DataCollector.topic, payload: 'a')
  Karafka.producer.flush_sync
end

class Consumer < Karafka::BaseConsumer
  def consume
    @done ||= Thread.new { Karafka::Server.stop }
  end
end

Karafka::App.routes.draw do
  topic DataCollector.topic do
    max_messages 1
    consumer Consumer
  end
end

Tracker.run do
  start = Time.monotonic

  Karafka::Server.run

  Time.monotonic - start
end

# Time taken: 0.11975190569792175
