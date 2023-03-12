# frozen_string_literal: true

# karafka topics migrate should not create topics when defined in routing and not existing but
# also not active

Karafka::Cli.prepare

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topic do
    config(active: false)
    consumer Consumer
  end
end

Karafka::Cli.start %w[topics migrate]

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

assert !cluster_topics.include?(DT.topic)
