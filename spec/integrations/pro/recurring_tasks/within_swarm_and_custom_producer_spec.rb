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

# Recurring tasks should work from a swarm with not used custom producer.
# If they don't this spec will run forever

setup_karafka do |config|
  config.recurring_tasks.producer = WaterDrop::Producer.new do |p_config|
    p_config.kafka = {
      'bootstrap.servers': 'localhost:999',
      'message.timeout.ms': 1_000
    }
  end
end

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

READER, WRITER = IO.pipe

Karafka::Pro::RecurringTasks.define('1.0.0') do
  schedule(id: SecureRandom.uuid, cron: '* * * * *', enabled: true) do
    WRITER.puts('1')
    WRITER.flush
  end
end

start_karafka_and_wait_until(mode: :swarm) do
  READER.gets && sleep(1)
end
