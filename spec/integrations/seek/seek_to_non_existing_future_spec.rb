# frozen_string_literal: true

# When we seek to a future where there are no offsets, we should seek to the first not yet
# produced message and get it

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    seek(Time.now + 120)

    DT[:offsets] << messages.first.offset

    # seek is async, so if we would produce too fast, we would actually skip this
    # message is it would not be considered latest
    sleep(2)

    produce(DT.topic, DT.uuids(1).first)
  end
end

draw_routes(Consumer)

# We start with one so we have a way to seek
produce(DT.topic, DT.uuids(1).first)

start_karafka_and_wait_until do
  DT[:offsets].size >= 5
end

assert_equal (0..4).to_a, DT[:offsets][0..4]
