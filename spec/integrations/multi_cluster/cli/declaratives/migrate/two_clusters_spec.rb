# frozen_string_literal: true

# Two migrations in one process should target their configured clusters independently.

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

primary_kafka = Karafka::App.config.kafka.dup.to_h
secondary_kafka = primary_kafka.merge(
  "bootstrap.servers": ENV.fetch("SECONDARY_KAFKA_BOOTSTRAP_SERVERS")
)

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    kafka(**primary_kafka)
    config
    consumer Consumer
  end

  topic DT.topics[1] do
    kafka(**secondary_kafka)
    config
    consumer Consumer
  end
end

primary_admin = Karafka::Admin.new(kafka: primary_kafka)
secondary_admin = Karafka::Admin.new(kafka: secondary_kafka)
topic_names = ->(admin) { admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) } }

assert Karafka::Cli::Topics::Migrate.new(kafka: primary_kafka).call
assert topic_names.call(primary_admin).include?(DT.topics[0])
assert !topic_names.call(primary_admin).include?(DT.topics[1])
assert !topic_names.call(secondary_admin).include?(DT.topics[0])
assert !topic_names.call(secondary_admin).include?(DT.topics[1])

assert Karafka::Cli::Topics::Migrate.new(kafka: secondary_kafka).call
assert topic_names.call(primary_admin).include?(DT.topics[0])
assert !topic_names.call(primary_admin).include?(DT.topics[1])
assert !topic_names.call(secondary_admin).include?(DT.topics[0])
assert topic_names.call(secondary_admin).include?(DT.topics[1])
