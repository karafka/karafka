# frozen_string_literal: true

# When eof is in use and `#eofed` crashes, it should emit an error but it should not cause any
# other crashes. Since `#eofed` does not deal with new data, it is not retried. It is up to the
# user to deal with any retry policies he may want to have
# eofed errors should not leak and processing should continue

setup_karafka(allow_errors: %w[consumer.eofed.error]) do |config|
  config.kafka[:'enable.partition.eof'] = true
end

Karafka.monitor.subscribe('error.occurred') do |event|
  DT[:errors] << event[:type]
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do
      DT[:count] << true
    end
  end

  def eofed
    raise
  end
end

draw_routes(Consumer)

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(1)) if DT.key?(:errors)

  DT[:count].size >= 20
end

assert_equal DT[:errors].uniq, %w[consumer.eofed.error]
