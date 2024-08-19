# frozen_string_literal: true

# When we decide to use recurring tasks and we do not define a schedule, it should create one
setup_karafka

draw_routes do
  recurring_tasks
end

assert !Karafka::Pro::RecurringTasks.schedule.nil?
