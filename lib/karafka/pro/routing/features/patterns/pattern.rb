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
          # regexp and not a "real" value. Underneath we define a dynamic topic, that is not
          # active, that can be a subject to normal flow validations, etc.
          class Pattern
            # Pattern regexp
            attr_accessor :regexp

            # Each pattern has its own "topic" that we use as a routing reference that we define
            # with non-existing topic for the routing to correctly pick it up for operations
            # Virtual topic name for initial subscription
            attr_reader :name

            # Associated created virtual topic reference
            attr_accessor :topic

            # Config for real-topic configuration during injection
            attr_reader :config

            # @param regexp [Regexp] regular expression to match topics
            # @param config [Proc] config for topic bootstrap
            def initialize(regexp, config)
              @regexp = regexp
              # This name is also used as the underlying matcher topic name
              # We generate it based on the regexp so within the same consumer group they are
              # always unique (checked by topic validations)
              #
              # This will not prevent users from creating a different regexps matching the same
              # topic but this minimizes simple mistakes
              #
              # This sub-part of sh1 should be unique enough and short-enough to use it here
              digest = Digest::SHA1.hexdigest(regexp.source)[8..16]
              @name = "karafka-pattern-#{digest}"
              @config = config
            end

            # @return [String] defined regexp representation as a string that is compatible with
            #   librdkafka expectations. We use it as a subscription name for initial patterns
            #   subscription start.
            def regexp_string
              "^#{regexp.source}"
            end

            # @return [Hash] hash representation of this routing pattern
            def to_h
              {
                regexp: regexp,
                name: name,
                regexp_string: regexp_string
              }.freeze
            end
          end
        end
      end
    end
  end
end
