# frozen_string_literal: true

# When we fully delay consumption and just run idle job, shutdown idle status should reflect that

setup_karafka

Karafka.monitor.subscribe('filtering.throttled') do
  DT[:done] << true
end

class Consumer < Karafka::BaseConsumer
  def consume; end

  def shutdown
    DT[:status] = used?
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    delay_by(60_000)
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  !DT[:done].empty?
end

assert_equal false, DT[:status]
