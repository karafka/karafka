# frozen_string_literal: true

# A simple case where we measure how long does it take to start and stop Karafka several times
# This serves as a baseline to determine if we can reboot the server in process for the development
# setup when using with code-reload.

setup_karafka

# How many topics connection tracking we want to benchmark
TOPICS = 5

100.times do
  TOPICS.times do |i|
    Karafka.producer.buffer(topic: DT.topics[i], payload: 'a')
  end

  Karafka.producer.flush_sync
end

class Consumer < Karafka::BaseConsumer
  def consume
    @consume ||= Thread.new { Karafka::Server.stop }
  end
end

Karafka::App.routes.draw do
  TOPICS.times do |i|
    topic DT.topics[i] do
      max_messages 1
      max_wait_time 1_000
      consumer Consumer
    end
  end
end

Tracker.run do
  start = Time.monotonic

  Karafka::Server.run

  Time.monotonic - start
end

# Time taken: 0.11975190569792175
