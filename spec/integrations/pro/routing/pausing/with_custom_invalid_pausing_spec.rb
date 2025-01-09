# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When overwriting the default pausing strategy on a per topic basis with something invalid,
# validations should kick in and stop it

setup_karafka

guarded = []

begin
  draw_routes(create_topics: false) do
    topic DT.topic do
      consumer Class.new(Karafka::BaseConsumer)
      pause(
        timeout: 1_000,
        max_timeout: 500,
        with_exponential_backoff: true
      )
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 1
end

begin
  draw_routes(create_topics: false) do
    topic DT.topic do
      consumer Class.new(Karafka::BaseConsumer)
      pause(
        timeout: 1_000,
        max_timeout: 500,
        with_exponential_backoff: false
      )
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 2
end

begin
  draw_routes(create_topics: false) do
    topic DT.topic do
      consumer Class.new(Karafka::BaseConsumer)
      pause(
        timeout: -100,
        max_timeout: 500
      )
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 3
end

assert_equal [1, 2, 3], guarded, guarded
