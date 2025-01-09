# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# karafka declarative topics management should ignore pattern topics because they are dynamic
# subscriptions for which we do not know the target name until the regexp match
Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    config(
      partitions: 2,
      'cleanup.policy': 'compact'
    )

    consumer Consumer
  end

  pattern(/test.*me-karafka-specs/) do
    consumer Consumer
  end
end

ARGV[0] = 'topics'
ARGV[1] = 'create'

Karafka::Cli.start

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

assert cluster_topics.include?(DT.topics[0])
assert cluster_topics.include?(DT.topics[1])

names = Karafka::App.routes.flat_map(&:topics).flat_map(&:to_a).map(&:name)

assert cluster_topics.include?(names[0])
assert cluster_topics.include?(names[1])
# Regexp names should not be used in declaratives
assert !cluster_topics.include?(names[2])
