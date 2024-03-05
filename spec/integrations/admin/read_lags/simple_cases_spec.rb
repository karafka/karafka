# frozen_string_literal: true

# A set of cases that can be easily tested together to save time

setup_karafka

draw_routes do
  topic DT.topics[0] do
    consumer Class.new
  end

  topic DT.topics[1] do
    active(false)
    consumer Class.new
  end

  topic DT.topics[2] do
    config(partitions: 2)
    consumer Class.new
  end
end

def read_lags(*args)
  Karafka::Admin.read_lags(*args)
end

CG1 = Karafka::App.config.group_id

produce_many(DT.topics[0], DT.uuids(10))
2.times { |i| produce_many(DT.topics[2], DT.uuids(10), partition: i) }

# Case 1 - CG that never consumed a non-existing topic
assert_equal(
  { 'nonexisting' => { 'na-topic1' => {}, 'na-topic2' => {} } },
  read_lags('nonexisting' => %w[na-topic1 na-topic2])
)

# Case 2 - CG that never run on existing routing setup with inactive topics
assert_equal(
  { CG1 => { DT.topics[0] => { 0 => -1 }, DT.topics[2] => { 0 => -1, 1 => -1 } } },
  read_lags({})
)

# Case 3 - CG that run on existing routing setup and consumed some data from one topic partition
Karafka::Admin.seek_consumer_group(
  CG1,
  { DT.topics[2] => { 1 => 3 } }
)

assert_equal(
  { CG1 => { DT.topics[0] => { 0 => -1 }, DT.topics[2] => { 0 => -1, 1 => 7 } } },
  read_lags({})
)
