# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka parallel segments distribute should work when there are no segments to distribute

setup_karafka

draw_routes do
  consumer_group DT.consumer_group do
    # No parallel_segments defined
    topic DT.topic do
      config(partitions: 2)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

produce_many(DT.topic, DT.uuids(10))

ARGV[0] = 'parallel_segments'
ARGV[1] = 'distribute'

results = capture_stdout do
  Karafka::Cli.start
end

assert results.include?('consumer groups with parallel segments configuration found')
