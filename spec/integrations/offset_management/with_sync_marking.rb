# frozen_string_literal: true

# Karafka should not raise any errors when we use mark_as_consumed!

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      mark_as_consumed!(message)
      DT[0] << message.offset
    end
  rescue StandardError
    exit! 5
  end
end

draw_routes(Consumer)

Array.new(100) { SecureRandom.uuid }.each { |value| produce(DT.topic, value) }

start_karafka_and_wait_until do
  DT[0].size >= 100
end
