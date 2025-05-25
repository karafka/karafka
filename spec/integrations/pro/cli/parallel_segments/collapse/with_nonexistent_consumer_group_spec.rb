# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka parallel segments collapse should fail when specified consumer group doesn't exist

setup_karafka

nonexistent_group = "nonexistent_group_#{SecureRandom.uuid}"

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 2,
      partitioner: ->(msg) { msg.key }
    )

    topic DT.topic do
      config(partitions: 2)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

produce_many(DT.topic, DT.uuids(10))

ARGV[0] = 'parallel_segments'
ARGV[1] = 'collapse'
ARGV[2] = '--groups'
ARGV[3] = nonexistent_group

failed = false

begin
  Karafka::Cli.start
rescue Karafka::Errors::ConsumerGroupNotFoundError
  failed = true
end

assert failed
