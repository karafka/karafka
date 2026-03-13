# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Karafka CLI info --extended should print pro feature details like virtual_partitions,
# long_running_job, throttling, expiring, delaying, and multiplexing

setup_karafka

draw_routes(create_topics: false) do
  consumer_group :pro_group do
    subscription_group :mx_sg do
      multiplexing(max: 3, min: 1)

      topic :vp_topic do
        consumer Class.new(Karafka::BaseConsumer)
        virtual_partitions(partitioner: ->(msg) { msg.raw_payload })
        long_running_job(true)
      end
    end

    topic :throttled_topic do
      consumer Class.new(Karafka::BaseConsumer)
      throttling(limit: 10, interval: 1_000)
    end

    topic :expiring_topic do
      consumer Class.new(Karafka::BaseConsumer)
      expiring(30_000)
    end

    topic :delaying_topic do
      consumer Class.new(Karafka::BaseConsumer)
      delaying(10_000)
    end

    topic :dlq_topic do
      consumer Class.new(Karafka::BaseConsumer)
      dead_letter_queue(topic: "dlq_target", max_retries: 5)
    end
  end
end

ARGV[0] = "info"
ARGV[1] = "--extended"

output = StringIO.new
Karafka.instance_variable_set(:@logger, ::Logger.new(output).tap { |l| l.level = ::Logger::INFO })

Karafka::Cli.start

results = output.string

# Verify routing section
assert results.include?("Routing")
assert results.include?("Consumer group: pro_group")

# Verify multiplexing on subscription group
assert results.include?("multiplexing: min=1, max=3")

# Verify Pro topic features
assert results.include?("virtual_partitions:")
assert results.include?("long_running_job:")
assert results.include?("throttling:")
assert results.include?("expiring:")
assert results.include?("delaying:")
assert results.include?("dead_letter_queue:")

# Verify DLQ details
assert results.include?('topic="dlq_target"')
assert results.include?("max_retries=5")

# Verify config and kafka config sections
assert results.include?("Config")
assert results.include?("Kafka Config")
