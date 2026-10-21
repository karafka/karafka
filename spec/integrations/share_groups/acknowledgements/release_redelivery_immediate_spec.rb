# frozen_string_literal: true

# Share group (KIP-932) released record is handed back by the broker right away (delivery count 2),
# without waiting for its acquisition lock (30 seconds by default) to expire.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << [message.delivery_count, Time.now]

      if message.delivery_count == 1
        mark_as_released(message)
      else
        mark_as_accepted(message)
      end
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

produce(DT.topic, "a")

start_karafka_and_wait_until do
  DT[:deliveries].size >= 2
end

assert_equal [1, 2], DT[:deliveries].map(&:first)
# Well below the 30 seconds lock duration
assert DT[:deliveries].last.last - DT[:deliveries].first.last < 10
