# frozen_string_literal: true

# When we use current matching strategy on the given offset that can be materialized, it should
# use the most recently used offset metadata even if it was assigned to a different offset

setup_karafka do |config|
  config.max_messages = 100
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep((10 - messages.first.offset) / 10.to_f)

    messages.each do |message|
      time = Time.now.to_f
      DT[:times] << time
      mark_as_consumed!(message, time.to_s)
    end

    DT[:groups] << messages.map(&:offset)
  end

  def shutdown
    DT[:metadata] << offset_metadata(cache: false)
  end
end

# Make sure we get 100 messages just not to deal with edge cases
class DelayThrottler < Karafka::Pro::Processing::Filters::Base
  def apply!(messages)
    @applied = false
    @cursor = nil

    return if messages.size >= 100

    @cursor = messages.first
    messages.clear
    @applied = true
  end

  def applied?
    @applied
  end

  def action
    applied? ? :seek : :skip
  end
end

DT[:iterator] = (0..9).cycle

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    filter(->(*) { DelayThrottler.new })
    virtual_partitions(
      partitioner: ->(_msg) { DT[:iterator].next },
      offset_metadata_strategy: :current
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:groups].size >= 10
end

assert_equal DT[:times].max.to_s, DT[:metadata].last
