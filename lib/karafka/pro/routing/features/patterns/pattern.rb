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
          # Karafka topic pattern object
          # It represents a topic that is not yet materialized and that contains a name that is a
          # regexp and not a "real" value. Underneath we define a dynamic topic, that is not active,
          # that can be a subject to normal flow validations, etc.
          class Pattern
            # Pattern regexp
            attr_accessor :regexp

            # Each pattern has its own "topic" that we use as a routing reference that we define with
            # non-existing topic for the routing to correctly pick it up for operations
            # Virtual topic name for initial subscription
            attr_reader :topic_name

            # @param regexp [Regexp] regular expression to match topics
            # @param config [Proc] config for topic bootstrap
            def initialize(regexp, config)
              @regexp = regexp
              @topic_name = "karafka-pattern-#{SecureRandom.hex(6)}"
              @config = config
            end

            # @return [Hash] hash representation of this routing pattern
            def to_h
              {
                regexp: regexp,
                topic_name: topic_name
              }.freeze
            end
          end
        end
      end
    end
  end
end
