# frozen_string_literal: true

# Karafka should publish the max.poll.interval.ms violations into the errors pipeline

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if @done

    sleep(15)

    @done = true
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

Karafka::App.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:error]
end

start_karafka_and_wait_until do
  DT.key?(:errors)
end

assert_equal :max_poll_exceeded, DT[:errors].last.code
