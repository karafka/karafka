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

# When insights are required, we should not proceed without them
# Because initial metrics fetch is slightly unpredictable (different with KRaft) and can be
# impacted by the cpu load, we simulate lack by patching the tracker so first first 10 seconds
# of running the process it returns no data

setup_karafka

module Patch
  include Karafka::Core::Helpers::Time

  def find(*args)
    @started_at ||= monotonic_now

    return {} if monotonic_now - @started_at < 10_000

    super
  end
end

Karafka::Processing::InlineInsights::Tracker.prepend(Patch)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:stats] << statistics
    DT[:stats] << insights
    DT[:stats_exist] << statistics?
    DT[:stats_exist] << insights?

    messages.each { |message| DT[:offsets] << message.offset }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    inline_insights(required: true)
  end
end

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:stats) &&
    DT[:stats_exist].include?(true) &&
    !DT[:stats].last.empty? &&
    DT[:offsets] == (0..9).to_a
end

assert_equal 0, DT[:stats].last['partition']
