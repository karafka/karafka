# frozen_string_literal: true

# karafka topics migrate should not create topics when defined in routing and not existing but
# also not active. Should also not run alignments when there are no declarative topics

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topic do
    config(active: false)
    consumer Consumer
  end
end

ARGV[0] = 'topics'
ARGV[1] = 'migrate'

Karafka::Cli.start

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

assert !cluster_topics.include?(DT.topic)
