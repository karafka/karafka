# frozen_string_literal: true

# karafka topics delete should never delete topics that are not defined in the routes

Karafka::Cli.prepare

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

# Draw it and lets reset routes there so it won't exist from CLI perspective
draw_routes do
  topic DT.topics[0] do
    consumer Consumer
  end
end

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

# Should exist before we want to delete anything
assert cluster_topics.include?(DT.topics[0])

Karafka::App.routes.clear
Karafka::Cli.start %w[topics delete]

# Should still exist because not part of the routing after routes were cleared
cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }
assert cluster_topics.include?(DT.topics[0])
