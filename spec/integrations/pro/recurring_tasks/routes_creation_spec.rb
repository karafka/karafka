# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we decide to use recurring tasks, in specs it should automatically migrate and create
# appropriate topics
setup_karafka

draw_routes do
  recurring_tasks(true)
end

# Should not fail as the topic should exist
schedules = Karafka::Admin.read_topic(
  Karafka::App.config.recurring_tasks.topics.schedules,
  0,
  1
)

assert_equal schedules, []

# Should not fail as the topic should exist
logs = Karafka::Admin.read_topic(
  Karafka::App.config.recurring_tasks.topics.logs,
  0,
  1
)

assert_equal logs, []
