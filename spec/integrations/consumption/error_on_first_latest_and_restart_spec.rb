# frozen_string_literal: true

# When starting from latest offset and having error on first run, Karafka has no offset to write
# as the first one, thus if restarted, it will against start from "latest".

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.initial_offset = 'latest'
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:done] << true

    raise
  end
end

draw_routes(Consumer)

start_karafka_and_wait_until do
  sleep(5)

  unless @sent
    @sent = true
    produce(DT.topic, '')
  end

  DT.key?(:done)
end

assert_equal(-1, fetch_next_offset(normalize: false))
