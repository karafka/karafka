# frozen_string_literal: true

# When using virtual partitions, we should easily consume data with the same instances on many of
# the batches even if error occurred.

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

class Consumer < Karafka::BaseConsumer
  def consume
    @count ||= 0
    @count += 1

    messages.each { |message| DT[0] << message.raw_payload }
    DT[1] << object_id

    raise StandardError if @count == 2
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitions(
        partitioner: ->(msg) { msg.raw_payload }
      )
    end
  end
end

start_karafka_and_wait_until do
  if DT[0].size >= 50
    true
  else
    produce_many(DT.topic, DT.uuids(5))

    sleep(1)
    false
  end
end

assert DT[0].size >= 6
# It should parallelize work
assert DT[1].uniq.size >= 2
assert_equal StandardError, DT[:errors].first[:error].class
assert_equal 'consumer.consume.error', DT[:errors].first[:type]
assert_equal 'error.occurred', DT[:errors].first.id
