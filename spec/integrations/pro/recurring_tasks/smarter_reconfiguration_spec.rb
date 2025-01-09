# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to reconfigure recurring tasks topics also via the direct config API
# This allows us to reconfigure things granularly.

setup_karafka(allow_errors: true)

code = nil

# Creating happens in a background thread and we want to catch errors, hence we need to trigger
# the creation inline
draw_routes(create_topics: false) do
  recurring_tasks(true) do |schedules_topic, logs_topic|
    schedules_topic.config.replication_factor = 2
    logs_topic.config.replication_factor = 2
  end
end

begin
  Karafka::Cli::Topics::Create.new.call
rescue Rdkafka::RdkafkaError => e
  code = e.code
end

assert_equal code, :invalid_replication_factor
