# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
