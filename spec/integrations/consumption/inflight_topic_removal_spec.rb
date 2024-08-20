# frozen_string_literal: true

# When topic in use is removed, Karafka should emit an error

setup_karafka(allow_errors: true)

Karafka.monitor.subscribe('error.occurred') do |event|
  DT[:errors] << event[:error]
end

class Consumer < Karafka::BaseConsumer
  def consume
    Thread.new do
      Karafka::Admin.delete_topic(DT.topic)
    rescue StandardError
      nil
    end

    sleep(1)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT[:errors].count >= 1
end

DT[:errors].each do |error|
  assert error.code == :unknown_partition || error.code == :unknown_topic_or_part
end
