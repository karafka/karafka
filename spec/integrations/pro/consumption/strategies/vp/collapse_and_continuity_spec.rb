# frozen_string_literal: true

# Karafka when with VP upon error should collapse the whole collective batch and should continue
# processing in the collapsed mode after a back-off until all the "infected" messages are done.
# After that, VPs should be resumed.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if messages.count == 1
    return if DT[:post_warmup].empty?

    unless DT[:post_collapse_run].empty?
      messages.each do |message|
        DT[:post_collapse] << [message.offset, object_id, collapsed?]
      end

      return
    end

    if collapsed?
      messages.each do |message|
        DT[:collapsed] << [message.offset, object_id]
      end
    else
      messages.each do |message|
        DT[:not_collapsed] << [message.offset, object_id]
      end

      if DT[:raised].empty?
        DT[:raised] << true
        raise StandardError
      end
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitions(
        partitioner: ->(message) { message.raw_payload }
      )
    end
  end
end

warmup = false

start_karafka_and_wait_until do
  unless warmup
    warmup = true
    produce_many(DT.topic, %w[0])
    DT[:post_warmup] << true
  end

  produce_many(DT.topic, (0..9).to_a.map(&:to_s).shuffle)

  sleep(10)

  produce_many(DT.topic, (0..9).to_a.map(&:to_s).shuffle)

  sleep(10)

  DT[:post_collapse_run] << true

  produce_many(DT.topic, (0..9).to_a.map(&:to_s).shuffle)

  sleep(0.1) until DT[:post_collapse].size >= 10

  true
end

assert_equal 20, DT[:not_collapsed].size
assert_equal 10, DT[:collapsed].size
assert_equal 10, DT[:post_collapse].size
