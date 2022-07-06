# frozen_string_literal: true

# Karafka should not raise any errors when we use mark_as_consumed!

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      mark_as_consumed!(message)
      DataCollector[0] << message
    end
  rescue StandardError
    exit! 5
  end
end

draw_routes(Consumer)

Array.new(100) { SecureRandom.uuid }.each { |value| produce(DataCollector.topic, value) }

start_karafka_and_wait_until do
  DataCollector[0].size >= 100
end
