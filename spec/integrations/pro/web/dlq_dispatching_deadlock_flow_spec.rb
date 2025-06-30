# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.concurrency = 20
  config.pause_timeout = 100
  config.pause_max_timeout = 100
  config.pause_with_exponential_backoff = false
end

setup_web do |config|
  config.tracking.interval = 1_000
  config.tracking.consumers.sync_threshold = 1
end

Karafka.monitor.subscribe('error.occurred') do
  DT[:errors] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    config(partitions: 100)
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 0
    )
  end
end

produce_many(DT.topics[0], DT.uuids(10_000))

start_karafka_and_wait_until do
  DT[:errors].size >= 1_000
end
