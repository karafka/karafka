# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should not allow for extremely small scale delays

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

failed = false

begin
  draw_routes(create_topics: false) do
    subscription_group :test do
      multiplexing(max: 10, min: 1, scale_delay: 500)

      topic DT.topics[0] do
        consumer Consumer
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
