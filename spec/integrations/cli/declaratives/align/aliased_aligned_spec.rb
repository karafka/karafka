# frozen_string_literal: true

# karafka topics align should do nothing when no changes needed despite changes being defined
# but then redefined by an alias

setup_karafka

Karafka::Admin.create_topic(DT.topics[0], 1, 1)
Karafka::Admin.create_topic(DT.topics[1], 2, 1)

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    active(false)
    config(
      partitions: 1,
      # This should not be used because it is overwritten by the one below
      "retention.bytes": 100_000,
      "log.retention.bytes": -1
    )
  end

  topic DT.topics[1] do
    active(false)
    config(partitions: 1)
  end
end

ARGV[0] = "topics"
ARGV[1] = "align"

Karafka::Cli.start

resources = [
  Karafka::Admin::Configs::Resource.new(type: :topic, name: DT.topics[0]),
  Karafka::Admin::Configs::Resource.new(type: :topic, name: DT.topics[1])
]

tr1, tr2 = Karafka::Admin::Configs.describe(resources)

tr1.configs.each do |config|
  case config.name
  when "retention.bytes"
    assert_equal "-1", config.value
  when "cleanup.policy"
    assert_equal "delete", config.value
  end
end

tr2.configs.each do |config|
  case config.name
  when "retention.bytes"
    assert_equal "-1", config.value
  when "cleanup.policy"
    assert_equal "delete", config.value
  end
end
