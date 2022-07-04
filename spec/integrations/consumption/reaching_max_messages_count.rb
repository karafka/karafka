# frozen_string_literal: true

# When we reach max messages prior to reaching max wait time, we should process that many messages
# without waiting max wait time

setup_karafka do |config|
  config.max_messages = 5
  # It should never go that far
  config.max_wait_time = 5_000
  config.shutdown_timeout = 120_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector[:data] << message
    end

    sleep(0.2)
  end
end

draw_routes(Consumer)

100.times { |data| produce(DataCollector.topic, data.to_s) }

started_at = Time.now.to_f

start_karafka_and_wait_until do
  DataCollector[:data].size >= 5
end

time_taken = Time.now.to_f - started_at

assert time_taken < 5
