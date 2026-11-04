# frozen_string_literal: true

# When running a share group (KIP-932) using the embedding API, we should get the embedded mode tag
# attached automatically to the Karafka process, the same way as for consumer groups.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
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

produce_many(DT.topic, DT.uuids(5))

Karafka::Embedded.start

sleep(0.1) until DT.key?(:accepted)

Karafka::Embedded.stop

assert_equal %w[mode:embedded], Karafka::Process.tags.to_a
