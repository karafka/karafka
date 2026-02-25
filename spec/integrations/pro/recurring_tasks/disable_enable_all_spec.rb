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

# We should be able to disable and enable back all the jobs in one go

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define("2.0.0") do
  10.times do |i|
    schedule(id: "j#{i}", cron: "* * * * *", previous_time: Time.now - 120_000) do
      DT[:"j#{i}"] << true
    end
  end
end

start_karafka_and_wait_until do
  Karafka::Pro::RecurringTasks.disable("*")
  sleep(1)
  Karafka::Pro::RecurringTasks.enable("*")
  sleep(1)
  Karafka::Pro::RecurringTasks.trigger("*")

  Array.new(10) { |i| DT[:"j#{i}"] }.all? { |accu| accu.size >= 5 }
end
