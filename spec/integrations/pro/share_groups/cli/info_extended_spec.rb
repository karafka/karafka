# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Karafka CLI info --extended should print share groups (KIP-932) alongside consumer groups: the
# share groups count, the share group with its subscription groups and topics, and the share
# topic features (acknowledgements and dead letter queue). Settings share topics do not use
# (initial offset and pausing) are printed only for consumer group topics.

setup_karafka

draw_routes(create_topics: false) do
  consumer_group :integration_group do
    topic :integration_topic do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  share_group :integration_share_group do
    topic :integration_share_topic do
      consumer Class.new(Karafka::ShareConsumer)
      acknowledgements(unacknowledged: :reject)
      dead_letter_queue(topic: "share_dlq_target", max_retries: 2)
    end
  end
end

ARGV.replace(%w[info --extended])

output = StringIO.new
Karafka.instance_variable_set(:@logger, ::Logger.new(output).tap { |l| l.level = ::Logger::INFO })

Karafka::Cli.start

ARGV.clear

results = output.string

assert results.include?("Consumer groups count: 1"), results
assert results.include?("Share groups count: 1"), results
assert results.include?("Subscription groups count: 2"), results

assert results.include?("Consumer group: integration_group (active)"), results
assert results.include?("Share group: integration_share_group (active)"), results
assert results.include?("kafka[group.id]: integration_share_group"), results
assert results.include?("Topic: integration_share_topic (active)"), results

# Share topic features should be detected and printed
assert results.include?("Features:"), results
assert results.include?("acknowledgements: unacknowledged=:reject"), results
assert results.include?("dead_letter_queue:"), results
assert results.include?("share_dlq_target"), results

routing = results.split("========== Config").first
consumer_group_section, share_group_section = routing.split("Share group: integration_share_group")

assert consumer_group_section.include?("initial_offset:"), results
assert consumer_group_section.include?("pause_timeout:"), results
assert !share_group_section.include?("initial_offset:"), results
assert !share_group_section.include?("pause_timeout:"), results
