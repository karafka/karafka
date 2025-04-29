# frozen_string_literal: true

# Karafka should emit an inline error if topic that was used was suddenly removed
# In async, it should emit it via the error pipeline

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'allow.auto.create.topics'] = false
end

draw_routes do
  topic DT.topics[0] do
    active false
  end

  topic DT.topics[1] do
    active false
  end
end

Karafka.producer.monitor.subscribe('error.occurred') do |event|
  DT[:errors] << event[:error]
end

Karafka.producer.produce_sync(topic: DT.topics[0], payload: 'test1')
Karafka::Admin.delete_topic(DT.topics[0])

begin
  Karafka.producer.produce_sync(topic: DT.topics[0], payload: 'test2')
rescue WaterDrop::Errors::ProduceError => e
  DT[:sync_errors] << e
end

# Based on exact timing librdkafka may try to deliver message but will fail, in such cases
# the timeout will happen. In case topic removal is faster, unknown partition
EXPECTED_ERRORS = %i[msg_timed_out unknown_partition].freeze

assert EXPECTED_ERRORS.include?(DT[:errors].last.cause.code)

# Sync here to force wait
Karafka.producer.produce_sync(topic: DT.topics[1], payload: 'test1')

Karafka::Admin.delete_topic(DT.topics[1])

handler = Karafka.producer.produce_async(topic: DT.topics[1], payload: 'test1')
handler.wait(raise_response_error: false)

DT[:errors].each do |error|
  if error.cause
    assert EXPECTED_ERRORS.include?(error.cause.code)
  else
    assert EXPECTED_ERRORS.include?(error.code)
  end
end
