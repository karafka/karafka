# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should match over postfix regexp

setup_karafka do |config|
  config.kafka[:'topic.metadata.refresh.interval.ms'] = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] = topic
  end
end

draw_routes(create_topics: false) do
  pattern(/.*#{DT.topics[1]}/) do
    consumer Consumer
  end
end

# If works, won't hang.
start_karafka_and_wait_until do
  unless @created
    sleep(5)
    produce_many("#{DT.topics[0]}-#{DT.topics[1]}", DT.uuids(1))
    @created = true
  end

  DT.key?(0)
end

# Make sure that the expansion of routing works and that proper subscription group is assigned
assert_equal 2, Karafka::App.subscription_groups.values.first.first.topics.size
assert_equal DT[0].subscription_group, Karafka::App.subscription_groups.values.first.first
