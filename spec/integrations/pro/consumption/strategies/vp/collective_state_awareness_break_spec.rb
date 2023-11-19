# frozen_string_literal: true

# We should be able to use `#failing?` to detect, that part of our work has already failed and
# that our current set of VPs will collapse.
#
# This can be used to stop processing when we know, it is going to be re-processed again

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 10
end

# Ensures, that we don't process at all unless we have at least 10 messages
# This eliminates the case of running a single virtual partition
class Buffer < Karafka::Pro::Processing::Filters::Base
  def apply!(messages)
    @applied = messages.count < 10

    return unless @applied

    @cursor = messages.first
    messages.clear
  end

  def action
    if applied?
      :pause
    else
      :skip
    end
  end

  def timeout
    250
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    if messages.first.offset.zero?
      sleep(0.1)

      raise StandardError
    else
      sleep(2)
    end

    if failing?
      DT[:failing] << true
    else
      DT[:ended] << true
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter ->(*) { Buffer.new }
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload.to_i % 10 }
    )
  end
end

produce_many(DT.topic, Array.new(100, &:to_s))

start_karafka_and_wait_until do
  DT[:failing].size >= 9
end

assert DT[:ended].empty?
