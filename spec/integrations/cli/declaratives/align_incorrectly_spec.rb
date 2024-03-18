# frozen_string_literal: true

# karafka topics align should crash if we want to align something with incorrect changes
# Please note this is NOT transactional

setup_karafka

# We create them with defaults first so they have default settings that will be altered by
# declaratives

Karafka::Admin.create_topic(DT.topics[0], 1, 1)

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    active(false)
    config(
      partitions: 1,
      'retention.ms': '-100',
      'cleanup.policy': 'delete'
    )
  end
end

ARGV[0] = 'topics'
ARGV[1] = 'align'

raised = false

begin
  Karafka::Cli.start
rescue Rdkafka::RdkafkaError
  raised = true
end

assert raised
