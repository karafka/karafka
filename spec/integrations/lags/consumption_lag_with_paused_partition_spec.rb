# frozen_string_literal: true

# When a partition is paused (e.g., during retry backoff), consumption lag should increase
# because messages are not being actively consumed during the pause period.

setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumption_lag] << messages.metadata.consumption_lag

    if DT[:paused].empty?
      DT[:paused] << true
      pause(messages.first.offset, 5_000)
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:consumption_lag].size >= 2
end

# After the pause, the consumption lag should be higher than the initial lag
# because messages sat unconsumed during the pause period
assert DT[:consumption_lag].last > DT[:consumption_lag].first,
  "Expected lag after pause (#{DT[:consumption_lag].last}) " \
  "to be greater than initial lag (#{DT[:consumption_lag].first})"
