# frozen_string_literal: true

# Share group (KIP-932) workers must not die when a user `#wrap` returns a falsy value. With 2
# workers and a wrap returning nil, all the records must still be consumed.

setup_karafka do |config|
  config.concurrency = 2
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end

  # Ends with nil on the consume flow - the framework must tolerate any return value here
  def wrap(action)
    yield

    nil if action == :consume
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

started_at = Time.now
produced = []

# Produce one record at a time once the previous one was consumed, so we get many consume jobs
start_karafka_and_wait_until do
  if (Time.now - started_at) > 60
    assert_equal(
      6,
      DT[:accepted].size,
      "workers died after falsy #wrap result: only #{DT[:accepted].size}/6 records consumed"
    )
  end

  if DT[:accepted].size == produced.size && produced.size < 6
    produced << SecureRandom.uuid
    produce(DT.topic, produced.last)
  end

  DT[:accepted].size >= 6
end

assert_equal produced.sort, DT[:accepted].sort
