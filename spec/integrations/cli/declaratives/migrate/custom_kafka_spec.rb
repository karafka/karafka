# frozen_string_literal: true

# A migration with custom Kafka configuration should use it for selection and all Admin work
# without changing the application-wide configuration.

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

working_kafka = Karafka::App.config.kafka.dup.to_h

draw_routes(create_topics: false) do
  topic DT.topic do
    kafka(**working_kafka)
    config
    consumer Consumer
  end
end

unreachable_kafka = { "bootstrap.servers": "127.0.0.1:9091" }
Karafka::App.config.kafka = unreachable_kafka
Karafka::App.config.admin.kafka = unreachable_kafka

assert Karafka::Cli::Topics::Migrate.new(kafka: working_kafka).call
assert_equal "127.0.0.1:9091", Karafka::App.config.kafka[:"bootstrap.servers"]
assert_equal "127.0.0.1:9091", Karafka::App.config.admin.kafka[:"bootstrap.servers"]

cluster_topics = Karafka::Admin
  .new(kafka: working_kafka)
  .cluster_info
  .topics
  .map { |topic| topic.fetch(:topic_name) }

assert cluster_topics.include?(DT.topic)
