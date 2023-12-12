# frozen_string_literal: true

# When we tick on VPs that were not created, we should only create one as we do not know how many
# we should pre-allocate

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end

  def tick
    raise unless messages.empty?

    DT[:ticks] << object_id
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic_job true # periodic is an alias, we support both
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

start_karafka_and_wait_until do
  DT[:ticks].count >= 5
end

assert_equal 1, DT[:ticks].uniq.size
