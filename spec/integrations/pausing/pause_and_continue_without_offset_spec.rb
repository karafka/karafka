# frozen_string_literal: true

# We should be able to pause without any arguments and then pause will pause on the
# consecutive offset

setup_karafka do |config|
  config.max_messages = 20
  config.pause_timeout = 2_000
  config.pause_max_timeout = 2_000
  config.pause_with_exponential_backoff = false
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:messages] << message.offset
    end

    DT[:times] << Time.now.to_f

    pause(:consecutive)
  end
end

draw_routes(Consumer)

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:messages].size >= 100
end

# All offsets need to be in the order
previous = nil
DT[:messages].each do |message|
  unless previous
    previous = message

    next
  end

  assert_equal previous + 1, message

  previous = message
end

previous = nil

# There needs to be a pause in between each batch
DT[:times].each do |time|
  unless previous
    previous = time

    next
  end

  assert((time - previous) * 1_000 >= 2_000)

  previous = time
end
