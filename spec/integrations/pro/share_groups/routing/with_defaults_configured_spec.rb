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

# Routing defaults should apply to share group (KIP-932) topics the same way as to consumer group
# topics: share-applicable settings from the defaults block are used unless the topic configured
# them itself.

setup_karafka

Consumer = Class.new(Karafka::ShareConsumer)

draw_routes(create_topics: false) do
  defaults do
    consumer Consumer
    acknowledgements(unacknowledged: :accept)
    dead_letter_queue(topic: "default-dlq", max_retries: 1)
  end

  share_group "sg" do
    topic "t1" do
      acknowledgements(unacknowledged: :reject)
      dead_letter_queue(topic: "custom-dlq", max_retries: 2)
    end

    topic "t2"
  end

  share_group "sg2" do
    topic "t3"
  end
end

t1, t2 = Karafka::App.routes.share_groups.first.topics.to_a
t3 = Karafka::App.routes.share_groups.last.topics.first

assert_equal Consumer, t1.consumer
assert_equal :reject, t1.acknowledgements.unacknowledged
assert_equal "custom-dlq", t1.dead_letter_queue.topic
assert_equal 2, t1.dead_letter_queue.max_retries

[t2, t3].each do |topic|
  assert_equal Consumer, topic.consumer
  assert_equal :accept, topic.acknowledgements.unacknowledged
  assert_equal "default-dlq", topic.dead_letter_queue.topic
  assert_equal 1, topic.dead_letter_queue.max_retries
end
