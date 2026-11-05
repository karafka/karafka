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

# The share group (KIP-932) dead letter queue routing settings should be validated: negative
# max_retries, unknown dispatch methods and invalid target topic names are rejected, while
# `topic: false` (reject without dispatch) and a regular target topic are accepted.

setup_karafka

Consumer = Class.new(Karafka::ShareConsumer)

def draw_dlq(**options)
  draw_routes(create_topics: false) do
    share_group "sg" do
      topic "t" do
        consumer Consumer
        dead_letter_queue(**options)
      end
    end
  end
end

invalid = {
  "routes.sg.t.dead_letter_queue.max_retries" => { topic: "dlq", max_retries: -1 },
  "routes.sg.t.dead_letter_queue.dispatch_method" => { topic: "dlq", dispatch_method: :produce },
  "routes.sg.t.dead_letter_queue.topic" => { topic: '#$%^&*(' }
}

invalid.each do |key, options|
  failed = false

  begin
    draw_dlq(**options)
  rescue Karafka::Errors::InvalidConfigurationError => e
    assert e.message.include?(key), e.message

    failed = true
  end

  assert failed, options

  clear_app_draws
end

# Rejecting without dispatching anywhere is valid
draw_dlq(topic: false, max_retries: 0)

topic = Karafka::App.routes.share_groups.first.topics.first

assert topic.dead_letter_queue?
assert_equal false, topic.dead_letter_queue.topic
assert_equal 0, topic.dead_letter_queue.max_retries

clear_app_draws

# A regular target topic with a sync dispatch is valid
draw_dlq(topic: "dlq-target", max_retries: 2, dispatch_method: :produce_sync)

topic = Karafka::App.routes.share_groups.first.topics.first

assert topic.dead_letter_queue?
assert_equal "dlq-target", topic.dead_letter_queue.topic
assert_equal :produce_sync, topic.dead_letter_queue.dispatch_method

clear_app_draws

# Without a topic the dead letter queue is not active
draw_dlq(max_retries: 2)

assert !Karafka::App.routes.share_groups.first.topics.first.dead_letter_queue?
