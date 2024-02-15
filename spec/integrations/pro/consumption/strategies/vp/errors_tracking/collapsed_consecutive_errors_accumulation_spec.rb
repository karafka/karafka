# frozen_string_literal: true

# When using virtual partitions and tracking errors, they under consecutive collapse should grow
# in terms of size

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:errors_collapsed] << errors_tracker.size if collapsed?

    raise StandardError
  end
end

DT[:iterator] = (0..9).cycle

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(_msg) { DT[:iterator].next }
    )
  end
end

produce_many(DT.topic, DT.uuids(500))

start_karafka_and_wait_until do
  DT[:errors_collapsed].include?(5)
end

assert_equal DT[:errors_collapsed][0..4], (1..5).to_a
