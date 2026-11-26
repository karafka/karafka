# frozen_string_literal: true

# Karafka::Admin.read_committed_offsets should return the committed offsets of existing consumer
# groups and an empty hash for each consumer group that does not exist, in the requested order,
# when both are requested together.

setup_karafka

draw_topics do
  topic DT.topics[0] do
    partitions 2
  end
end

produce_many(DT.topics[0], DT.uuids(10), partition: 1)

first_group = "#{DT.group}-first"
second_group = "#{DT.group}-second"
first_missing = "#{DT.group}-missing-first"
second_missing = "#{DT.group}-missing-second"

Karafka::Admin.seek_consumer_group(first_group, { DT.topics[0] => { 0 => 0, 1 => 7 } })
Karafka::Admin.seek_consumer_group(second_group, { DT.topics[0] => { 1 => 3 } })

requested = [first_missing, first_group, second_missing, second_group]

results = Karafka::Admin.read_committed_offsets(requested)

assert_equal requested, results.keys
assert_equal({}, results[first_missing])
assert_equal({}, results[second_missing])
assert_equal({ DT.topics[0] => { 0 => 0, 1 => 7 } }, results[first_group])
assert_equal({ DT.topics[0] => { 1 => 3 } }, results[second_group])
