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

# We should be able to reference both `#processing_lag` and `consumption_lag` even when we
# had delay and no data would be consumed prior.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def shutdown
    messages.metadata.processing_lag
    messages.metadata.consumption_lag
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    delay_by(100_000)
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  sleep(5)
end
