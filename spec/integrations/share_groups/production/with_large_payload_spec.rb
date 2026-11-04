# frozen_string_literal: true

# Share groups (KIP-932) should handle records near the broker size limit correctly. Several ~500KB
# payloads (below the default 1MB limit) should be acquired, consumed intact and accepted exactly
# once.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:payloads] << message.raw_payload
      mark_as_accepted(message)
    end
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

payloads = %w[a b c].map { |char| char * 500_000 }

payloads.each { |payload| produce(DT.topic, payload) }

start_karafka_and_wait_until do
  DT[:payloads].size >= payloads.size && sleep(1)
end

assert_equal payloads.size, DT[:payloads].size
assert_equal payloads.sort, DT[:payloads].sort
