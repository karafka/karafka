# frozen_string_literal: true

# Karafka::Admin.describe_consumer_groups should report a consumer group that was never created as
# dead with no members, not raise an error. librdkafka reports its type as classic.

setup_karafka

missing = Karafka::Admin.describe_consumer_groups([DT.group]).first

assert_equal DT.group, missing[:group_id]
assert_equal :dead, missing[:state]
assert_equal :classic, missing[:type]
assert_equal [], missing[:members]
