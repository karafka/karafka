# frozen_string_literal: true

# Karafka::Admin.describe_topics should describe the existing topics and report a topic that does
# not exist with its error, instead of failing the whole call.

setup_karafka

Karafka::Admin.create_topic(DT.topic, 1, 1)

missing_name = "#{DT.topic}-missing"

missing, existing = Karafka::Admin.describe_topics([missing_name, DT.topic])

assert_equal missing_name, missing[:name]
assert_equal :unknown_topic_or_part, missing[:error].code
assert_equal nil, missing[:topic_id]
assert_equal [], missing[:partitions]

assert_equal DT.topic, existing[:name]
assert_equal nil, existing[:error]
assert_equal 1, existing[:partitions].size
