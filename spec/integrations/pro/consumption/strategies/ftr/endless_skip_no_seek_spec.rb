# frozen_string_literal: true

# When we create a filter that just skips all the messages and does not return the cursor message,
# we should never seek and just go on with incoming messages

exit 1

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

class CustomFilter
  def filter!(messages)
    messages.clear
  end

  def filtered?
    true
  end

  def throttled?
    false
  end

  def cursor
    nil
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter
  end
end

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  # This needs to run for a while as on slow CIs things pick up slowly
  sleep(15)
end

assert_equal elements[0..1], DT[0]
