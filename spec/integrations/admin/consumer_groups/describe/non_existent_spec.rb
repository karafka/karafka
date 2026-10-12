# frozen_string_literal: true

# Karafka::Admin.describe_consumer_group should report a consumer group that was never created as
# dead with no members, not raise an error.

setup_karafka

missing = Karafka::Admin.describe_consumer_group(DT.group)

assert_equal DT.group, missing[:group_id]
assert_equal :dead, missing[:state]
assert_equal [], missing[:members]
