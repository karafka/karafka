# frozen_string_literal: true

# karafka topics migrate should create share-group topics with their declarative config

setup_karafka

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      config(partitions: 2)
      consumer Class.new(Karafka::ShareConsumer)
    end
  end
end

ARGV[0] = "topics"
ARGV[1] = "migrate"

Karafka::Cli.start

topic = Karafka::Admin.cluster_info.topics.find { |t| t.fetch(:topic_name) == DT.topic }

assert_equal 2, topic.fetch(:partition_count)
