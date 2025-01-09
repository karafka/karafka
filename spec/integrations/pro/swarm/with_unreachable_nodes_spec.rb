# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should fail when we define nodes that cannot be reached

setup_karafka do |config|
  config.swarm.nodes = 3
end

guarded = []

begin
  draw_routes(create_topics: false) do
    consumer_group 'regular' do
      topic 't1' do
        swarm(nodes: (100..200))
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << true
end

Karafka::App.routes.clear

begin
  draw_routes(create_topics: false) do
    consumer_group 't2' do
      topic 'regular' do
        swarm(nodes: [100, 123])
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << true
end

Karafka::App.routes.clear

begin
  draw_routes(create_topics: false) do
    consumer_group 't2' do
      topic 'regular' do
        swarm(nodes: [2])
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << true
end

assert_equal 2, guarded.size
