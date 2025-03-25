# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# This PR illustrates how partitioning based on constant payload content basically cancels the
# potential of VPs by creating only single virtual partition.

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 100
  config.concurrency = 10
  config.max_wait_time = 1_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    start = Time.now.to_f

    DT[0] << messages.size

    sleep(rand / 10.to_f)

    DT[:ranges] << (start..Time.now.to_f)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.payload['key'] }
    )
  end
end

produce_many(
  DT.topic,
  Array.new(1_000) { { key: '1', data: rand }.to_json }
)

start_karafka_and_wait_until do
  DT[0].sum >= 1_000
end

# Prove that in no cases we overlap because the key is always the same not allowing
# for any work distribution
# If they do not overlap, it means

ranges = DT[:ranges]

ranges.each do |current_range|
  (ranges - [current_range]).each do |compared_range|
    assert_no_overlap(current_range, compared_range)
  end
end
