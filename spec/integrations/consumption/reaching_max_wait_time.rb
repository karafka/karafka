# frozen_string_literal: true

# When we have a max_wait_time and we did not reach the requested number of messages, we should
# wait for at most the max time we requested. We also should not wait shorter period of time, as
# the messages number is not satisfied.

setup_karafka do |config|
  config.max_messages = 200
  config.max_wait_time = 5_000
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector[:data] << message.offset
    end

    sleep(0.2)
  end
end

draw_routes(Consumer)

produce(DataCollector.topic, 'data')

started_at = Time.now.to_f

start_karafka_and_wait_until do
  DataCollector[:data].size >= 1
end

time_taken = Time.now.to_f - started_at

assert time_taken > 5
