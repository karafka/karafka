# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we decide to use recurring tasks and we do not define a schedule, it should create one
setup_karafka

draw_routes do
  recurring_tasks(true)
end

assert !Karafka::Pro::RecurringTasks.schedule.nil?
