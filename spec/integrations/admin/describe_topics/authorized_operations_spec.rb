# frozen_string_literal: true

# Karafka::Admin.describe_topics should report the operations the client is authorized to perform
# on each existing topic as symbols when requested, nil for a topic that does not exist, and nil
# by default.

setup_karafka

Karafka::Admin.create_topic(DT.topic, 1, 1)

missing_name = "#{DT.topic}-missing"

missing, existing = Karafka::Admin.describe_topics(
  [missing_name, DT.topic],
  include_authorized_operations: true
)

operations = existing[:authorized_operations]

assert operations.all?(Symbol), operations
assert (%i[read write describe] - operations).empty?, operations

assert_equal :unknown_topic_or_part, missing[:error].code
assert_equal nil, missing[:authorized_operations]

assert_equal nil, Karafka::Admin.describe_topics([DT.topic]).first[:authorized_operations]
