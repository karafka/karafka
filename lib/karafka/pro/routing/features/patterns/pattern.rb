# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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

            # @param name [String, Symbol, nil] name or the regexp for building the topic name or
            #   nil if we want to make it based on the regexp content
            # @param regexp [Regexp] regular expression to match topics
            # @param config [Proc] config for topic bootstrap
            def initialize(name, regexp, config)
              @regexp = regexp
              # This name is also used as the underlying matcher topic name
              #
              # It can be used provided by the user in case user wants to use exclusions of topics
              # or we can generate it if irrelevant.
              #
              # We generate it based on the regexp so within the same consumer group they are
              # always unique (checked by topic validations)
              #
              # This will not prevent users from creating a different regexps matching the same
              # topic but this minimizes simple mistakes
              #
              # This sub-part of sh1 should be unique enough and short-enough to use it here
              digest = Digest::SHA256.hexdigest(safe_regexp.source)[8..16]
              @name = name ? name.to_s : "karafka-pattern-#{digest}"
              @config = config
            end

            # @return [String] defined regexp representation as a string that is compatible with
            #   librdkafka expectations. We use it as a subscription name for initial patterns
            #   subscription start.
            def regexp_string
              "^#{safe_regexp.source}"
            end

            # @return [Hash] hash representation of this routing pattern
            def to_h
              {
                regexp: regexp,
                name: name,
                regexp_string: regexp_string
              }.freeze
            end

            private

            # Since pattern building happens before validations and we rely internally on the fact
            # that regexp is provided and nothing else, we here "sanitize" the regexp for our
            # internal usage. Karafka will not run anyhow because our post-routing contracts will
            # prevent it from running but internally in this component we need to ensure, that
            # prior to the validations we operate on a regexp
            #
            # @return [Regexp] returns a regexp always even if what we've received was not a regexp
            def safe_regexp
              # This regexp will never match anything
              regexp.is_a?(Regexp) ? regexp : /$a/
            end
          end
        end
      end
    end
  end
end
