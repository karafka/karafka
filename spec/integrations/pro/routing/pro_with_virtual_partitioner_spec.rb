# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# I should be able to define a topic consumption with virtual partitioner.
# It should not impact other jobs and the default should not have it.

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Class.new(Karafka::BaseConsumer)
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end

  topic DT.topics[1] do
    consumer Class.new(Karafka::BaseConsumer)
  end

  topic DT.topics[2] do
    consumer Class.new(Karafka::BaseConsumer)
  end
end

assert Karafka::App.routes.first.topics[0].virtual_partitions?
assert_equal false, Karafka::App.routes.first.topics[1].virtual_partitions?
assert_equal false, Karafka::App.routes.first.topics[2].virtual_partitions?
