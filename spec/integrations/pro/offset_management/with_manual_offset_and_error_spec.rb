# frozen_string_literal: true

# Using manual offset management under rebalance and error happening, we should start from the
# last place that we were, even when there were many batches down the road and no checkpointing

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 2
  config.license.token = pro_license_token
end

class Consumer < Karafka::BaseConsumer
  def consume
    @runs ||= 0

    messages.each do |message|
      DT[:offsets] << message.offset
    end

    @runs += 1

    return unless @runs == 4

    # The -1 will act as a divider so it's easier to spec things
    DT[:split] << DT[:offsets].size
    raise StandardError
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      manual_offset_management true
    end
  end
end

Thread.new do
  loop do
    produce(DT.topic, '1', partition: 0)

    sleep(0.1)
  rescue StandardError
    nil
  end
end

start_karafka_and_wait_until do
  DT[:offsets].size >= 10
end

split = DT[:split].first

before = DT[:offsets][0..(split - 1)]
after = DT[:offsets][split..100]

# It is expected to reprocess all since consumer was created even when there are more batches
assert_equal [], before - after
