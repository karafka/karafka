# frozen_string_literal: true

# Share group (KIP-932) shutdown: when no records were received, no consumer was built, so
# `#shutdown` should not run.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    DT[0] << 1
  end

  def shutdown
    DT[0] << 1
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

start_karafka_and_wait_until do
  sleep(2)
  true
end

assert_equal 0, DT[0].size
