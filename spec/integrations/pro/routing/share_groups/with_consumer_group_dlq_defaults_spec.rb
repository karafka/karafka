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

# A Pro consumer-group DLQ default with consumer-only options (`independent:`, `strategy:`) must
# not raise when a share group is drawn, and must not reach share topics or the share group in
# any form, as the routing `defaults` block applies to consumer-group topics only.

setup_karafka

STRATEGY = ->(_errors_tracker, _attempt) { :dispatch }

draw_routes(create_topics: false) do
  defaults do
    dead_letter_queue(topic: "dlq", independent: true, strategy: STRATEGY)
  end

  consumer_group "cg" do
    topic "regular" do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  share_group "sg" do
    topic "share-topic" do
      consumer Class.new(Karafka::ShareConsumer)
    end
  end
end

cg_topic = Karafka::App.routes.consumer_groups.first.topics.first
sg_topic = Karafka::App.routes.share_groups.first.topics.first

assert cg_topic.dead_letter_queue?
assert_equal "dlq", cg_topic.dead_letter_queue.topic
assert_equal true, cg_topic.dead_letter_queue.independent
assert_equal STRATEGY, cg_topic.dead_letter_queue.strategy

assert !sg_topic.respond_to?(:dead_letter_queue)
assert !sg_topic.to_h.key?(:dead_letter_queue)
assert !Karafka::App.routes.share_groups.first.to_h.to_s.include?("dlq")
