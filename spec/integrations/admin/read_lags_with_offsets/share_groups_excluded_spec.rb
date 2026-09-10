# frozen_string_literal: true

# When read_lags_with_offsets is used without explicit groups, it enumerates the routing to find
# groups to query. Share groups (KIP-932) do not store classic committed offsets, so they must be
# excluded from this default enumeration instead of being queried via the consumer-offsets API
# and reported as phantom consumer groups with meaningless data.

setup_karafka

TOPIC = DT.topics[0]

draw_topics do
  topic TOPIC do
    partitions 1
  end
end

draw_routes(create_topics: false) do
  consumer_group DT.groups[0] do
    topic TOPIC do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  share_group "lags-share-group" do
    topic TOPIC do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

produce_many(TOPIC, DT.uuids(10))
Karafka::Admin.seek_consumer_group(DT.groups[0], { TOPIC => { 0 => 3 } })

lags = Karafka::Admin::ConsumerGroups.read_lags_with_offsets

# The consumer group must be present with its real lag data
assert lags.key?(DT.groups[0]), lags.keys
assert_equal 3, lags.fetch(DT.groups[0]).fetch(TOPIC).fetch(0).fetch(:offset)

# The share group must not be reported at all
assert !lags.key?("lags-share-group"), lags.keys
