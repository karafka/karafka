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

# Karafka should react to direct quiet from commanding

setup_karafka
setup_web

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:is] = true
  end
end

Karafka.monitor.subscribe("app.quieting") do
  DT[:flow] << true
end

Karafka.monitor.subscribe("app.quiet") do
  DT[:flow] << true
end

draw_routes(Consumer)

elements = DT.uuids(1)
produce_many(DT.topic, elements)

Thread.new do
  sleep(0.1) until DT.key?(:is)

  Karafka::Web::Pro::Commanding::Dispatcher.request(
    "consumers.quiet",
    {},
    matchers: { process_id: Karafka::Web.config.tracking.consumers.sampler.process_id }
  )
end

# Nothing needed. Won't stop unless commanding works
start_karafka_and_wait_until do
  DT[:flow].size >= 2
end
