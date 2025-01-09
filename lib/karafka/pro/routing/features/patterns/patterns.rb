# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Patterns < Base
          # Representation of groups of topics
          class Patterns < ::Karafka::Routing::Topics
            # Finds first pattern matching given topic name
            #
            # @param topic_name [String] topic name that may match a pattern
            # @return [Karafka::Routing::Pattern, nil] pattern or nil if not found
            # @note Please keep in mind, that there may be many patterns matching given topic name
            #   and we always pick the first one (defined first)
            def find(topic_name)
              @accumulator.find { |pattern| pattern.regexp =~ topic_name }
            end
          end
        end
      end
    end
  end
end
