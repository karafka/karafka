# frozen_string_literal: true

# karafka topics align should be able to align declarative topics that have their settings changed

setup_karafka

# We create them with defaults first so they have default settings that will be altered by
# declaratives

Karafka::Admin.create_topic(DT.topics[0], 1, 1)
Karafka::Admin.create_topic(DT.topics[1], 2, 1)

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    active(false)
    config(
      partitions: 1,
      'retention.ms': 86_500_000,
      'cleanup.policy': 'delete'
    )
  end

  topic DT.topics[1] do
    active(false)

    config(
      partitions: 1,
      'retention.ms': 76_500_000,
      'cleanup.policy': 'compact,delete'
    )
  end
end

ARGV[0] = 'topics'
ARGV[1] = 'align'

Karafka::Cli.start

# Give a bit of time to cluster to sync up settings.
# This is needed on slow CIs
sleep(2)

resources = [
  Karafka::Admin::Configs::Resource.new(type: :topic, name: DT.topics[0]),
  Karafka::Admin::Configs::Resource.new(type: :topic, name: DT.topics[1])
]

tr1, tr2 = Karafka::Admin::Configs.describe(resources)

tr1.configs.each do |config|
  case config.name
  when 'retention.ms'
    assert_equal config.value, 86_500_000.to_s
  when 'cleanup.policy'
    assert_equal config.value, 'delete'
  end
end

tr2.configs.each do |config|
  case config.name
  when 'retention.ms'
    assert_equal config.value, 76_500_000.to_s
  when 'cleanup.policy'
    assert_equal config.value, 'compact,delete'
  end
end
