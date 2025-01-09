# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should not allow for using VP with DLQ without retries

setup_karafka do |config|
  config.concurrency = 10
end

guarded = []

begin
  draw_routes(create_topics: false) do
    consumer_group DT.consumer_group do
      topic DT.topic do
        consumer Class.new(Karafka::BaseConsumer)
        virtual_partitions(
          partitioner: ->(msg) { msg.raw_payload }
        )
        dead_letter_queue(
          topic: 'test',
          max_retries: 0
        )
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 1
end

assert_equal [1], guarded
