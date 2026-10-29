# frozen_string_literal: true

# Share group (KIP-932): when the server is stopped and the share consumer `#shutdown` hook hangs,
# it should force a shutdown (exit code 2).

setup_karafka(allow_errors: true) { |config| config.shutdown_timeout = 1_000 }

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| mark_as_accepted(message) }
    DT[0] << true
  end

  def shutdown
    # This will "fake" a hanging job
    sleep(100)
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

produce(DT.topic, "1")

start_karafka_and_wait_until do
  if DT[0].empty?
    false
  else
    sleep 1
    true
  end
end

# Karafka is expected to exit with 2 from a different thread, so we just block here
sleep
