# frozen_string_literal: true

# A case where we have a multiple workers consuming data from many partition and piping it to
# another topic (dynamic)
#
# We start counting time since first message arrival until last message delivered

become_pro!

setup_karafka do |config|
  config.concurrency = 5
  config.max_messages = 10_000
end

MAX_MESSAGES_PER_PARTITION = 100_000

PARTITIONS_COUNT = 5

# Topic where we want to pipe the data
TARGET_TOPIC = SecureRandom.uuid

::Karafka::Admin.create_topic(TARGET_TOPIC, PARTITIONS_COUNT, 1)

class Consumer < Karafka::BaseConsumer
  def consume
    pipe_many_async(topic: TARGET_TOPIC, messages: messages)
  end

  private

  # @param pipe_message [Hash]
  # @param message [Karafka::Messages::Message]
  def enhance_pipe_message(pipe_message, message)
    pipe_message[:partition] = message.metadata.partition
  end
end

Karafka::App.routes.draw do
  consumer_group DT.consumer_group do
    subscription_group do
      multiplexing(min: 5, max: 5)

      topic 'benchmarks_00_05' do
        consumer Consumer
      end
    end

    topic TARGET_TOPIC do
      active(false)
      config(partitions: 5)
    end
  end
end

Karafka.producer.monitor.subscribe('message.acknowledged') do
  $start ||= Time.monotonic

  $total += 1

  next unless $total >= 500_000

  $stop ||= Time.monotonic
  Thread.new { Karafka::Server.stop }
end

Tracker.run(messages_count: MAX_MESSAGES_PER_PARTITION * PARTITIONS_COUNT) do
  $start = nil
  $stop = nil
  $total = 0

  Karafka::App.config.internal.status.reset!
  Karafka::Server.run

  $stop - $start
end

# Time taken: 44.05786718800664
# Messages per second: 11348.71095476245
