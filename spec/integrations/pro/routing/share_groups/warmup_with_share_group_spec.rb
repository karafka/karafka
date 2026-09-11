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

# A Pro app that describes a share group in its routing must be able to run Karafka::App.warmup
# (fired by every server start) without crashing: the Pro swarm routing contract validates node
# assignments of consumer-group topics only and must skip share-group topics, which carry no
# swarm assignment API.

setup_karafka

draw_routes(create_topics: false) do
  consumer_group "cg" do
    topic "regular" do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  share_group "sg" do
    topic "share-topic" do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

# Must not raise (before the fix this crashed with NoMethodError on topic.swarm)
Karafka::App.warmup

assert true
