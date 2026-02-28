# frozen_string_literal: true

# Karafka when started and stopped should go through all the lifecycle stages

Karafka::App.monitor.subscribe("connection.listener.fetch_loop") do |event|
  DT[:offsets] << event[:client].query_watermark_offsets(DT.topic, 0)
  produce(DT.topic, "1")
end

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

start_karafka_and_wait_until do
  DT[:offsets].any? { |offsets| offsets.last >= 10 }
end

assert_equal [0], DT[:offsets].map(&:first).uniq
