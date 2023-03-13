# frozen_string_literal: true

# karafka topics migrate should work with topics that are not actively consumed but are managed
# using Karafka

Karafka::Cli.prepare

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topic do
    active false
  end
end

Karafka::Cli.start %w[topics migrate]

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

assert cluster_topics.include?(DT.topic)
