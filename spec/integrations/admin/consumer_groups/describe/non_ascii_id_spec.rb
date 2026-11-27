# frozen_string_literal: true

# Karafka::Admin.describe_consumer_groups should describe a consumer group with a UTF-8 non-ASCII
# id. librdkafka returns ids as BINARY, so the describe loop must match them by bytes.

setup_karafka

non_ascii_id = "#{DT.group}-zażółć"

missing, ascii = Karafka::Admin.describe_consumer_groups([non_ascii_id, DT.group])

assert_equal non_ascii_id.b, missing[:group_id].b
assert_equal :dead, missing[:state]
assert_equal [], missing[:members]
assert_equal DT.group, ascii[:group_id]
assert_equal :dead, ascii[:state]
