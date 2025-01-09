# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should not allow for usage of patterns with direct assignments

setup_karafka

failed = false

begin
  draw_routes(create_topics: false) do
    pattern(/#{DT.topic}/) do
      consumer Class.new(Karafka::BaseConsumer)
      assign(0)
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
