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

# When using versioned schedules, we should be able to upgrade
# There should be no exceptions or crashes and new schedule should work

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define('1.1.0') do
  schedule(id: 'run', cron: '* * * * *', previous_time: Time.now - 600_000) do
    DT[:done] = true
  end
end

start_karafka_and_wait_until(reset_status: true) do
  unless @dispatched
    Karafka::Pro::RecurringTasks.trigger('run')
    @dispatched = true
  end

  DT.key?(:done)
end

setup_karafka

Karafka::Pro::RecurringTasks.define('1.2.0') do
  schedule(id: 'run', cron: '* * * * *') do
    DT[:done2] = true
  end
end

start_karafka_and_wait_until(reset_status: true) do
  unless @dispatched2
    sleep(2)
    Karafka::Pro::RecurringTasks.trigger('run')
    @dispatched2 = true
  end

  DT.key?(:done2)
end
