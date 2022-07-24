# frozen_string_literal: true

# When using virtual partitions, we should easily consume data with the same instances on many of
# the batches even if error occurred.

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

    raise StandardError if @count == 2
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

start_karafka_and_wait_until do
  if DataCollector[0].size >= 50
    true
  else
    elements = Array.new(5) { SecureRandom.uuid }
    elements.each { |data| produce(DataCollector.topic, data) }
    sleep(1)
    false
  end
end

assert DataCollector[0].size >= 6
# It should parallelize work
assert DataCollector[1].uniq.size >= 2
assert_equal StandardError, DataCollector[:errors].first[:error].class
assert_equal 'consumer.consume.error', DataCollector[:errors].first[:type]
assert_equal 'error.occurred', DataCollector[:errors].first.id
