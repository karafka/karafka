# frozen_string_literal: true

# A set of cases that can be easily tested together to save time

setup_karafka

CG1 = DT.topics[0]
CG2 = DT.topics[1]

draw_routes do
  consumer_group CG1 do
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

  consumer_group CG2 do
    # Same on purpose
    topic DT.topics[0] do
      consumer Class.new
    end

    topic DT.topics[3] do
      active(false)
      consumer Class.new
    end

    topic DT.topics[4] do
      config(partitions: 2)
      consumer Class.new
    end
  end
end

def read_lags_with_offsets(*)
  Karafka::Admin.read_lags_with_offsets(*)
end

produce_many(DT.topics[0], DT.uuids(10))
2.times { |i| produce_many(DT.topics[2], DT.uuids(10), partition: i) }
2.times { |i| produce_many(DT.topics[4], DT.uuids(10), partition: i) }

NA = { lag: -1, offset: -1 }.freeze

Karafka::Admin.seek_consumer_group(
  CG1,
  { DT.topics[2] => { 0 => 3 } }
)

Karafka::Admin.seek_consumer_group(
  CG2,
  { DT.topics[4] => { 1 => 4 } }
)

assert_equal(
  Karafka::Admin.read_lags_with_offsets[CG1],
  { DT.topics[0] => { 0 => NA }, DT.topics[2] => { 0 => { offset: 3, lag: 7 }, 1 => NA } }
)

assert_equal(
  Karafka::Admin.read_lags_with_offsets[CG2],
  { DT.topics[0] => { 0 => NA }, DT.topics[4] => { 0 => NA, 1 => { offset: 4, lag: 6 } } }
)
