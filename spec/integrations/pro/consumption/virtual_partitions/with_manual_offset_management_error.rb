# frozen_string_literal: true

# When using manual offset management and not marking at all, upon error we should get all the
# messages again as no checkpointing should happen.
# This effectively means, that we should process data in loops

MUTEX = Mutex.new

setup_karafka(allow_errors: true) do |config|
  config.license.token = pro_license_token
  config.concurrency = 5
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each do |message|
      DT[:messages] << message.raw_payload
    end

    MUTEX.synchronize do
      return if DT[:errors].size > 30

      DT[:errors] << true

      raise StandardError
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitioner ->(msg) { msg.raw_payload }
      manual_offset_management true
    end
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:errors].size >= 30
end

# We should restart over and over again so same messages should come
assert DT.data[:messages].size >= 200
assert_equal 100, DT.data[:messages].uniq.size
