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

# The Pro server CLI contract must handle topic include/exclude filters also when the routing
# contains a share group: an unknown topic name should produce a clean validation error (before
# the fix it crashed with NoMethodError calling #patterns on the share group) and existing topic
# names - consumer or share - should validate successfully.

setup_karafka

# Redraws the mixed consumer + share routing. We redraw before every validation because
# App.subscription_groups narrowing is destructive on the memoized routing state, so each
# validation needs a fresh draw to be independent
def redraw_mixed_routing
  clear_app_draws

  draw_routes(create_topics: false) do
    consumer_group "cg" do
      topic "regular-topic" do
        consumer Class.new(Karafka::BaseConsumer)
      end
    end

    share_group "sg" do
      topic "share-topic" do
        consumer Class.new(Karafka::BaseConsumer)
      end
    end
  end
end

activity_manager = Karafka::App.config.internal.routing.activity_manager
contract = Karafka::App.config.internal.cli.contract

# Unknown topic must produce a validation error, not a NoMethodError crash
redraw_mixed_routing
activity_manager.include(:topics, "totally-unknown-topic")

failed = false

begin
  contract.validate!(activity_manager.to_h)
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?("topic"), e.message

  failed = true
end

assert failed

activity_manager.clear

# Existing consumer-group topic name validates
redraw_mixed_routing
activity_manager.include(:topics, "regular-topic")
contract.validate!(activity_manager.to_h)

activity_manager.clear

# Existing share-group topic name validates too
redraw_mixed_routing
activity_manager.include(:topics, "share-topic")
contract.validate!(activity_manager.to_h)

activity_manager.clear

assert true
