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

# We should be able to trigger all tasks even if they are suppose to run once a year

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define("1.0.0") do
  schedule(id: "a", cron: "0 12 31 12 *", enabled: false) do
    DT[:a] = true
  end

  schedule(id: "b", cron: "0 12 31 12 *", enabled: false) do
    DT[:b] = true
  end

  schedule(id: "c", cron: "0 12 31 12 *", previous_time: Time.now - 120_000) do
    DT[:c] = true
  end
end

start_karafka_and_wait_until do
  unless @dispatched
    Karafka::Pro::RecurringTasks.trigger("*")
    @dispatched = true
  end

  DT.key?(:a) && DT.key?(:b) && DT.key?(:c)
end
