# frozen_string_literal: true

# Karafka should be able to easily consume all the messages from earliest (default)

setup_karafka(allow_errors: true) do |config|
  config.license.token = pro_license_token
  config.concurrency = 5
  config.max_messages = 1_000
  config.max_wait_time = 500
end

if ENV.key?('PRODUCER')
  loop do
    100.times do
      Karafka.producer.produce_async(
        topic: 'hahahaha',
        payload: '1'
      )
    end

    sleep(0.5)
  end
end


class Consumer < Karafka::Pro::BaseConsumer
  def consume
    if rand < 0.001
      p 'nieok'
      raise StandardError
    end

    p 'ok'

    messages.each do |message|
    #  DataCollector[message.metadata.partition] << message.raw_payload
    end

    sleep(rand(10) / 1_000.to_f)
  end
end

require 'datadog/statsd'
require 'karafka/instrumentation/vendors/datadog/listener'

listener = ::Karafka::Instrumentation::Vendors::Datadog::Listener.new do |config|
  config.client = Datadog::Statsd.new('localhost', 8125)
  # Publish host as a tag alongside the rest of tags
  config.default_tags = ["host:#{Socket.gethostname}"]
end

Karafka.monitor.subscribe(listener)


draw_routes do
  consumer_group 'hhahahaha' do
    topic 'hahahaha' do
      consumer Consumer
      virtual_partitioner ->(_) { rand(12).to_s }
    end
  end
end

#elements = Array.new(100) { SecureRandom.uuid }
#elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  false
end
