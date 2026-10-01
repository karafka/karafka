# frozen_string_literal: true

# Share group (KIP-932) subscribed to an existing and a never existing topic keeps consuming the
# existing one, does not create the missing one and starts and stops cleanly.

# Depending on the metadata state, polling may report the missing topic
setup_karafka(allow_errors: %w[connection.client.poll.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[message.topic] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
    end

    topic DT.topics[1] do
      consumer Consumer
    end
  end
end

setup_share_group(DT.topics[0])

elements = DT.uuids(10)
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  if DT[DT.topics[0]].size >= 10
    DT[:consumed_at] = Time.now unless DT.key?(:consumed_at)

    # Give it some time to operate with the missing topic
    Time.now - DT[:consumed_at] > 5
  else
    false
  end
end

assert_equal elements.sort, DT[DT.topics[0]].sort

topics_names = Karafka::Admin.cluster_info.topics.map { |topic| topic[:topic_name] }
assert !topics_names.include?(DT.topics[1])
