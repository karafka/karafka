# frozen_string_literal: true

# Karafka should be able to recover from non-critical error when using lrj the same way as any
# normal consumer even if it happens often.
# It should not impact processing order.

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.license.token = pro_license_token
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    raise StandardError if rand(2).zero?

    messages.each { |message| DT[0] << message.offset }

    sleep 2

    produce_many(DT.topic, DT.uuids(5))
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
    end
  end
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[0].size >= 50 && DT[:errors].size >= 5
end

previous = nil

DT[0].each do |offset|
  unless previous
    previous = offset
    next
  end

  assert_equal previous + 1, offset

  previous = offset
end
