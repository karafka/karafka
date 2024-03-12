# frozen_string_literal: true

# When configured with inactive visible, we should get their lags.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active(false)
    consumer Class.new
  end

  topic DT.topics[1] do
    active(false)
    config(partitions: 2)
    consumer Class.new
  end
end

def read_lags(details)
  Karafka::Admin.read_lags(details, active_topics_only: false)
end

CG1 = Karafka::App.config.group_id

produce_many(DT.topics[0], DT.uuids(10))
2.times { |i| produce_many(DT.topics[1], DT.uuids(10), partition: i) }

# Case 1 - CG that never run on existing routing setup with inactive topics
assert_equal(
  { CG1 => { DT.topics[0] => { 0 => -1 }, DT.topics[1] => { 0 => -1, 1 => -1 } } },
  read_lags({})
)

# Case 2 - CG that run on existing routing setup and consumed some data from one topic partition
Karafka::Admin.seek_consumer_group(
  CG1,
  { DT.topics[1] => { 1 => 3 } }
)

assert_equal(
  { CG1 => { DT.topics[0] => { 0 => -1 }, DT.topics[1] => { 0 => -1, 1 => 7 } } },
  read_lags({})
)
