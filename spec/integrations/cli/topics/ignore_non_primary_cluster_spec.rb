# frozen_string_literal: true

# In case of using a custom `#kafka` setup for a topic, we should consider it a secondary and we
# should not run anything against it

Karafka::Cli.prepare

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    # We set those settings differently as any deviation in bootstrap.servers should cause
    # karafka to consider this as a different cluster
    kafka('bootstrap.servers': '127.0.0.1:9091')
    consumer Consumer
  end
end

Karafka::Cli.start %w[topics create]

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

# Topic should not exist because it should belong to a non-default cluster
assert !cluster_topics.include?(DT.topics[0])
