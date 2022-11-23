# frozen_string_literal: true

# Ruby had some header related bugs in 3.0.2. This PR checks that all works as expected

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages
      .select { |message| message.headers.key?('iteration') }
      .select { |message| message.headers['iteration'].to_i > 5 }
      .each do |message|
        1_000.times do
          message.headers.transform_keys!(&:to_s)
          message.headers.transform_keys!(&:to_sym)
        end

        DT[:selected] << message.offset
      end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitions(
        partitioner: ->(_) { rand }
      )
    end
  end
end

10.times do |i|
  produce_many(DT.topic, DT.uuids(10), headers: { 'iteration' => i.to_s, 'transform' => 'test' })
end

start_karafka_and_wait_until do
  DT[:selected].count >= 40
end
