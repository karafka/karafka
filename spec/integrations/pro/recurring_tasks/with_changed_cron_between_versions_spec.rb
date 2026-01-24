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

# When cron changes between versions, we should be using the new one.

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

past_date = Time.now + (7 * 24 * 60 * 60)
PAST_CRON = "0 0 #{past_date.day} #{past_date.month} *".freeze

Karafka::Pro::RecurringTasks.define('1.0.0') do
  schedule(id: 'run', cron: PAST_CRON, previous_time: Time.now - 60_000) do
    # Should never run until cron schedule is updated
    raise
  end
end

start_karafka_and_wait_until(reset_status: true) do
  sleep(10)
end

setup_karafka

Karafka::Pro::RecurringTasks.define('1.2.0') do
  schedule(id: 'run', cron: '* * * * *') do
    DT[:done] = true
  end
end

start_karafka_and_wait_until(reset_status: true) do
  DT.key?(:done)
end
