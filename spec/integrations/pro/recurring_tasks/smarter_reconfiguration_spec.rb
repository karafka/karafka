# frozen_string_literal: true

# We should be able to reconfigure recurring tasks topics also via the direct config API
# This allows us to reconfigure things granularly.

setup_karafka(allow_errors: true)

code = nil

begin
  draw_routes do
    recurring_tasks(true) do |schedules_topic, logs_topic|
      schedules_topic.config.replication_factor = 2
      logs_topic.config.replication_factor = 2
    end
  end
rescue Rdkafka::RdkafkaError => e
  code = e.code
end

assert_equal code, :invalid_replication_factor
