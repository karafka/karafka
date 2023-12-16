# frozen_string_literal: true

# Skip until all explicit modules gems are released due to loading issues
exit if RUBY_VERSION.include?('2.7.8')

# When the idle job kicks in before we had a chance to process any data, it should still have
# access to empty messages batch with proper offset positions (-1001) and no messages.
# Web tracking should pick it up and not fail

setup_karafka
setup_web

Karafka.monitor.subscribe('filtering.throttled') do
  DT[:done] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] << true
  end

  def shutdown
    DT[:messages] << messages
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    delay_by(60_000)
  end
end

produce_many(DT.topic, DT.uuids(15))

start_karafka_and_wait_until do
  !DT[:done].empty?
end
