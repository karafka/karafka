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
      DataCollector[:messages] << message
    end

    MUTEX.synchronize do
      return if DataCollector[:errors].size > 30

      DataCollector[:errors] << true

      raise StandardError
    end
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
      virtual_partitioner ->(msg) { msg.raw_payload }
      manual_offset_management true
    end
  end
end

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector[:errors].size >= 30
end

# We should restart over and over again so same messages should come
assert DataCollector.data[:messages].size >= 200
assert_equal 100, DataCollector.data[:messages].map(&:raw_payload).uniq.size
