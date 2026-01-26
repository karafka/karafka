# frozen_string_literal: true

# karafka topics migrate should work with topics that are not actively consumed but are managed
# using Karafka

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topic do
    active false
  end
end

ARGV[0] = "topics"
ARGV[1] = "migrate"

Karafka::Cli.start

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

assert cluster_topics.include?(DT.topic)
