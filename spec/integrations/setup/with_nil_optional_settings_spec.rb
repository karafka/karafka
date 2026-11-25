# frozen_string_literal: true

# Karafka should treat nil as not set for optional settings that also accept false and consume

setup_karafka do |config|
  config.license.token = nil
  config.oauth.token_provider_listener = nil
  config.internal.processing.worker_job_call_wrapper = nil
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:payloads] << message.raw_payload }
  end
end

draw_routes(Consumer)

elements = DT.uuids(5)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:payloads].size >= 5
end

assert_equal elements, DT[:payloads]
assert !Karafka.pro?
