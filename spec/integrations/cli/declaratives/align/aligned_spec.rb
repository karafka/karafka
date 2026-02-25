# frozen_string_literal: true

# karafka topics align should do nothing when no changes needed

setup_karafka

Karafka::Admin.create_topic(DT.topics[0], 1, 1)
Karafka::Admin.create_topic(DT.topics[1], 2, 1)

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    active(false)
    config(partitions: 1)
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
  when "retention.ms"
    assert_equal config.value, "604800000"
  when "cleanup.policy"
    assert_equal config.value, "delete"
  end
end

tr2.configs.each do |config|
  case config.name
  when "retention.ms"
    assert_equal config.value, "604800000"
  when "cleanup.policy"
    assert_equal config.value, "delete"
  end
end
