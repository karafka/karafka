# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# In VPs we should also be safeguarded when trying to start transaction inside of a transaction

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    transaction do
      transaction do
        nil
      end
    end
  rescue Karafka::Errors::TransactionAlreadyInitializedError
    DT[:done] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(_msg) { rand(10).to_s }
    )
  end
end

produce_many(DT.topic, DT.uuids(10))

# No assertions needed, would hang if would not crash
start_karafka_and_wait_until do
  DT.key?(:done)
end
