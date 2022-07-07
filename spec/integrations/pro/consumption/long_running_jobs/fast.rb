# frozen_string_literal: true

# Fast jobs should also not have any problems (though not recommended) when running as lrj

setup_karafka do |config|
  config.max_messages = 1
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.license.token = pro_license_token
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    DataCollector[0] << messages.first.raw_payload
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
      long_running_job true
    end
  end
end

payloads = Array.new(20) { SecureRandom.uuid }

payloads.each { |payload| produce(DataCollector.topic, payload) }

start_karafka_and_wait_until do
  DataCollector[0].size >= 20
end

assert_equal payloads, DataCollector[0]
