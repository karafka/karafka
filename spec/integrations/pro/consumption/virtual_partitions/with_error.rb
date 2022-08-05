# frozen_string_literal: true

# When Karafka consumes in the VP mode and error happens in any of the processing units we allow
# the rest to finish the work and we restart the processing from the first offset on a batch.
# This spec raises only one error once

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
end

class Consumer < Karafka::Pro::BaseConsumer
  MUTEX = Mutex.new

  def consume
    messages.each { |message| DT[0] << message.raw_payload }
    DT[1] << object_id

    MUTEX.synchronize do
      next unless DT[2].empty?

      DT[2] << true

      raise StandardError
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitioner ->(msg) { msg.raw_payload }
    end
  end
end

elements = Array.new(5) { SecureRandom.uuid }
elements.each { |data| produce(DT.topic, data) }

start_karafka_and_wait_until do
  # We have 5 messages but we retry thus it needs to be minimum 6
  DT[0].size >= 6
end

assert DT[0].size >= 6
# It should parallelize work
assert DT[1].uniq.size >= 2
assert_equal 1, DT[:errors].size
assert_equal StandardError, DT[:errors].first[:error].class
assert_equal 'consumer.consume.error', DT[:errors].first[:type]
assert_equal 'error.occurred', DT[:errors].first.id
assert_equal 5, DT[0].uniq.size
