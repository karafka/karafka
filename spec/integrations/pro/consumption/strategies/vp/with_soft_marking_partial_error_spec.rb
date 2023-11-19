# frozen_string_literal: true

# When using `mark_as_consumed` in virtual partitions, we should do virtual marking with correct
# state location materialization on errors. This prevents us from excessive re-processing because
# as much data as possible is marked as consumed

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 2
  config.max_messages = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.offset == 80 && !collapsed?

      DT[:collapsed_offsets] << message.offset if collapsed?

      mark_as_consumed(message) unless message.offset == 99
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitions(
        partitioner: ->(_msg) { [0, 1].sample }
      )
    end
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:collapsed_offsets].include?(99)
end
