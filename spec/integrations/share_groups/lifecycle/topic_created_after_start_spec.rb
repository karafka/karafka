# frozen_string_literal: true

# Share group (KIP-932) subscribed to a topic that does not exist yet starts fine and once the
# topic is created, its records are consumed without a restart.

# Depending on the metadata state, polling may report the missing topic
setup_karafka(allow_errors: %w[connection.client.poll.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
    end
  end
end

# `share.auto.offset.reset` is a group level setting, so we point the share group at the earliest
# record using a helper topic, as the main one must not exist yet
setup_share_group(DT.topics[1], DT.group)

elements = DT.uuids(10)

Thread.new do
  # Let Karafka run for a while against the missing topic
  sleep(5)

  Karafka::Admin.create_topic(DT.topics[0], 1, 1)
  produce_many(DT.topics[0], elements)
end

start_karafka_and_wait_until do
  DT[:consumed].size >= 10
end

assert_equal elements.sort, DT[:consumed].sort
