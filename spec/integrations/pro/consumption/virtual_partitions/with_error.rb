# frozen_string_literal: true

# When Karafka consumes in the VP mode and error happens in any of the processing units we allow
# the rest to finish the work and we restart the processing from the first offset on a batch.

class Listener
  def on_error_occurred(event)
    DataCollector[:errors] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    @count ||= 0
    @count += 1

    messages.each { |message| DataCollector[0] << message.raw_payload }
    DataCollector[1] << object_id

    raise StandardError if @count == 1
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
      virtual_partitioner ->(msg) { msg.raw_payload }
    end
  end
end

elements = Array.new(5) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  # We have 5 messages but we retry thus it needs to be minimum 6
  DataCollector[0].size >= 6
end

assert DataCollector[0].size >= 6
# It should parallelize work
assert DataCollector[1].uniq.size >= 2
assert_equal StandardError, DataCollector[:errors].first[:error].class
assert_equal 'consumer.consume.error', DataCollector[:errors].first[:type]
assert_equal 'error.occurred', DataCollector[:errors].first.id
assert_equal 5, DataCollector[0].uniq.size
