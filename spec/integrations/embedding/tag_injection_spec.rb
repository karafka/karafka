# frozen_string_literal: true

# When running Karafka using the embedding API, we should get appropriate tag attached
# automatically to the Karafka process

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(10)
produce_many(DT.topic, elements)

# Run Karafka
Karafka::Embedded.start

sleep(0.1) until DT[0].size >= 1

Karafka::Embedded.stop

assert_equal Karafka::Process.tags.to_a, %w[embedded]
