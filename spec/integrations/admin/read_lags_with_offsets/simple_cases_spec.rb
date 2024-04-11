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

def read_lags_with_offsets(details)
  Karafka::Admin.read_lags_with_offsets(details, active_topics_only: false)
end

CG1 = Karafka::App.config.group_id

produce_many(DT.topics[0], DT.uuids(10))
2.times { |i| produce_many(DT.topics[1], DT.uuids(10), partition: i) }

NA = { lag: -1, offset: -1 }.freeze

# Case 1 - CG that never run on existing routing setup with inactive topics
assert_equal(
  { CG1 => { DT.topics[0] => { 0 => NA }, DT.topics[1] => { 0 => NA, 1 => NA } } },
  read_lags_with_offsets({})
)

# Case 2 - CG that run on existing routing setup and consumed some data from one topic partition
Karafka::Admin.seek_consumer_group(
  CG1,
  { DT.topics[1] => { 1 => 3 } }
)

assert_equal(
  {
    CG1 => {
      DT.topics[0] => { 0 => NA },
      DT.topics[1] => { 0 => NA, 1 => { offset: 3, lag: 7 } }
    }
  },
  read_lags_with_offsets({})
)
