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

# We should be able to assign to ourselves multiple topics in one CG

setup_karafka

class Consumer1 < Karafka::BaseConsumer
  def consume
    DT[:t1] = true
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    DT[:t2] = true
  end
end

draw_routes do
  topic DT.topics.first do
    consumer Consumer1
    assign(true)
  end

  topic DT.topics.last do
    consumer Consumer2
    assign(true)
  end
end

produce_many(DT.topics.first, DT.uuids(1))
produce_many(DT.topics.last, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:t1) && DT.key?(:t2)
end
