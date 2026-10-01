# frozen_string_literal: true

# Share group (KIP-932) routes can be built from the cluster info: topics matching a regexp are
# found via the admin and subscribed to automatically within one share group.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[message.topic] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

MATCH = SecureRandom.uuid

t1 = "#{DT.topics[0]}-#{MATCH}"
t2 = "#{DT.topics[1]}-#{MATCH}"

setup_share_group(t1)
setup_share_group(t2)

draw_routes(create_topics: false) do
  share_group DT.group do
    Karafka::Admin
      .cluster_info
      .topics
      .map { |topic| topic[:topic_name] }
      .grep(/#{MATCH}/o)
      .each do |name|
        topic name do
          consumer Consumer
        end
      end
  end
end

assert_equal [t1, t2].sort, Karafka::App.routes.first.topics.map(&:name).sort

elements = DT.uuids(10)
produce_many(t1, elements)
produce_many(t2, elements)

start_karafka_and_wait_until do
  DT[t1].size >= 10 && DT[t2].size >= 10
end

assert_equal elements.sort, DT[t1].sort
assert_equal elements.sort, DT[t2].sort
