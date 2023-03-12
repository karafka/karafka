# frozen_string_literal: true

# karafka topics delete should not delete existing topics defined in routes but opted out

Karafka::Cli.prepare

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

# This will create them automatically
draw_routes do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    consumer Consumer
  end
end

Karafka::App.routes.clear

draw_routes do
  topic DT.topics[0] do
    config(active: false)
    consumer Consumer
  end

  topic DT.topics[1] do
    config(active: false)
    consumer Consumer
  end
end

Karafka::Cli.start %w[topics delete]

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

assert cluster_topics.include?(DT.topics[0])
assert cluster_topics.include?(DT.topics[1])
