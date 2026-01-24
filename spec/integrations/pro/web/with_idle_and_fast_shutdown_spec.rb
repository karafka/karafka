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

# When the idle job kicks in before we had a chance to process any data, it should still have
# access to empty messages batch with proper offset positions (-1001) and no messages.
# Web tracking should pick it up and not fail

setup_karafka
setup_web

Karafka.monitor.subscribe('filtering.throttled') do
  DT[:done] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] << true
  end

  def shutdown
    DT[:messages] << messages
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    delay_by(60_000)
  end
end

produce_many(DT.topic, DT.uuids(15))

start_karafka_and_wait_until do
  !DT[:done].empty?
end
