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

# When we start cron and publish several events, the state should always be published after
# each command execution. This allows us to make assumptions about the topic data structure when
# buildings things like UI.

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define("1.0.0") do
  schedule(id: "run", cron: "* * * * *", enabled: false) do
    DT[:attempts] << true
  end
end

start_karafka_and_wait_until(reset_status: true) do
  Karafka::Pro::RecurringTasks.disable("run")
  sleep(1)
  Karafka::Pro::RecurringTasks.enable("run")
  sleep(1)
  Karafka::Pro::RecurringTasks.trigger("run")
  sleep(1)

  DT[:attempts].size >= 10
end

previous = nil

keys = Karafka::Admin
  .read_topic(Karafka::App.config.recurring_tasks.topics.schedules.name, 0, 21)
  .map(&:key)

assert keys.count("state:schedule") >= 10

# This is time sensitive and due to "every 500ms" and the other thread disable/enable it could
# happen that it is published twice next to each other creating randomness
keys.delete_if { |action| action == "state:schedule" }

keys.each do |event|
  assert previous != event, keys

  previous = event
end
