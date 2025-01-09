# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we decide to assign certain set of partitions and run in swarm, this set of partitions
# should match the nodes mapping

# We also should not be able to allocate partitions that are not assigned

setup_karafka do |config|
  config.swarm.nodes = 3
end

failed = false

begin
  draw_routes(create_topics: false) do
    topic :a do
      consumer Class.new
      # We want to assign 5 partitions but only 3 are in use
      assign(0..5)
      swarm(
        nodes: {
          0 => [0],
          1 => [1],
          2 => [2]
        }
      )
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed

Karafka::App.routes.clear

failed = false

begin
  draw_routes(create_topics: false) do
    topic :a do
      consumer Class.new
      # We want to assign 5 partitions but only 3 are in use
      assign(0..3)
      swarm(
        nodes: {
          0 => [0, 1, 2],
          1 => [3],
          2 => [4]
        }
      )
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
