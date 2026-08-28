# frozen_string_literal: true

# When reading a topic with a Time start offset that is beyond the timestamp of the last
# message, there is nothing "from that time onwards" to return: the result must be empty.
# Returning anything else means tooling built on this API (debugging, data inspection)
# receives messages that are all OLDER than the requested time, presented as if they matched.
#
# Time resolution via librdkafka yields -1 ("no message at or after this time"), which must
# not be reinterpreted as the relative "last N messages" form of the negative numeric offsets.

setup_karafka

Karafka::Admin.create_topic(DT.topic, 1, 1)

produce_many(DT.topic, DT.uuids(10))

# Sanity: a Time before all messages returns them from the start
from_past = Karafka::Admin.read_topic(DT.topic, 0, 5, Time.now - 60)
assert_equal 5, from_past.size
assert_equal 0, from_past.first.offset

# A Time beyond the last message must yield no messages at all
from_future = Karafka::Admin.read_topic(DT.topic, 0, 5, Time.now + 60)

assert_equal(
  [],
  from_future.map(&:offset),
  "expected no messages for a time beyond the last message, got offsets: " \
  "#{from_future.map(&:offset)}"
)
