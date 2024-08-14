# frozen_string_literal: true

# When we have old cg and new cg and topics with offsets to migrate, it should work
# When we indicate that old group should stay, it should not be removed.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
    config(partitions: 1)
  end

  topic DT.topics[1] do
    active false
    config(partitions: 5)
  end
end

messages = Array.new(20) { rand.to_s }

produce_many(DT.topics[0], messages)

5.times { |partition| produce_many(DT.topics[1], messages, partition: partition) }

PREVIOUS_NAME = SecureRandom.uuid
NEW_NAME = SecureRandom.uuid

Karafka::Admin.seek_consumer_group(
  PREVIOUS_NAME,
  {
    DT.topics[0] => { 0 => 10 },
    DT.topics[1] => Array.new(5) { |i| [i, i + 1] }.to_h
  }
)

Karafka::Admin.rename_consumer_group(
  PREVIOUS_NAME,
  NEW_NAME,
  [DT.topics[0], DT.topics[1]],
  delete_previous: false
)

migrated = Karafka::Admin.read_lags_with_offsets(
  { NEW_NAME => [DT.topics[0], DT.topics[1]] }
)

assert_equal 10, migrated[NEW_NAME][DT.topics[0]][0][:offset]

5.times do |i|
  assert_equal i + 1, migrated[NEW_NAME][DT.topics[1]][i][:offset]
end

old = Karafka::Admin.read_lags_with_offsets(
  { PREVIOUS_NAME => [DT.topics[0], DT.topics[1]] }
)

assert_equal 10, old[PREVIOUS_NAME][DT.topics[0]][0][:offset]

5.times do |i|
  assert_equal i + 1, old[PREVIOUS_NAME][DT.topics[1]][i][:offset]
end
