# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should fail when we define nodes that do not have any assignments

setup_karafka(allow_errors: true) do |config|
  config.swarm.nodes = 5
end

guarded = []

begin
  draw_routes(create_topics: false) do
    consumer_group 'regular' do
      topic 't1' do
        swarm(nodes: (1..2))
        consumer Class.new
      end
    end
  end

  Karafka::Swarm::Supervisor.new.run
rescue Karafka::Errors::InvalidConfigurationError
  guarded << true
end

assert_equal 1, guarded.size
