# frozen_string_literal: true

# Karafka::Admin.read_committed_offsets should return an empty hash for each consumer group that
# does not exist, in the requested order, when only such consumer groups are requested.

setup_karafka

missing_groups = Array.new(3) { |i| "#{DT.group}-missing-#{i}" }

results = Karafka::Admin.read_committed_offsets(missing_groups)

assert_equal missing_groups, results.keys
assert_equal({}, results[missing_groups[0]])
assert_equal({}, results[missing_groups[1]])
assert_equal({}, results[missing_groups[2]])
