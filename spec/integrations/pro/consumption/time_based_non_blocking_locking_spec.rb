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

# We should be able to lock in a non-blocking fashion and then lock should expire based on time

setup_karafka do |config|
  config.max_messages = 1
  config.concurrency = 1
end

class Consumer1 < Karafka::BaseConsumer
  def consume
    subscription_groups_coordinator.pause(
      topic.subscription_group,
      1,
      timeout: 5_000
    )

    DT[0] << Time.now.to_f
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    DT[1] << Time.now.to_f
  end
end

draw_routes do
  subscription_group :a do
    topic DT.topics[0] do
      consumer Consumer1
    end
  end

  subscription_group :b do
    topic DT.topics[1] do
      consumer Consumer2
    end
  end
end

produce_many(DT.topics[0], DT.uuids(10))
produce_many(DT.topics[1], DT.uuids(10))

start_karafka_and_wait_until do
  DT[0].size >= 3 && DT[1].size >= 10
end
