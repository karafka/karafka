# frozen_string_literal: true

# karafka topics align should fail naming the topic and the configuration unknown to the cluster
# and should not apply any other configuration change

setup_karafka

Karafka::Admin.create_topic(DT.topic, 1, 1)

draw_routes(create_topics: false) do
  topic DT.topic do
    active false
    config(
      partitions: 1,
      "retention.msx": 86_400_000,
      "retention.bytes": 1_000_000
    )
  end
end

ARGV[0] = "topics"
ARGV[1] = "align"

results = capture_stdout do
  Karafka::Cli.start
rescue SystemExit => e
  DT[:status] = e.status
end

assert_equal 1, DT[:status]
assert results.include?("#{DT.topic} has configuration unknown to the cluster: retention.msx.")
assert !results.include?("Updated")
assert !results.include?("no configurations to align")

resource = Karafka::Admin::Configs::Resource.new(type: :topic, name: DT.topic)
retention_bytes = Karafka::Admin::Configs.describe(resource).first.configs.find do |config|
  config.name == "retention.bytes"
end

assert_equal "-1", retention_bytes.value
