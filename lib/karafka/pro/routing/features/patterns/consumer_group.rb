# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Patterns < Base
          # Expansion of the consumer groups routing component to work with patterns
          module ConsumerGroup
            # @param args [Object] whatever consumer group accepts
            def initialize(*args)
              super
              @patterns = Patterns.new([])
            end

            # @return [::Karafka::Pro::Routing::Features::Patterns::Patterns] created patterns
            def patterns
              @patterns
            end

            # Creates the pattern for topic matching with appropriate virtual topic
            # @param regexp_or_name [Symbol, String, Regexp] name of the pattern or regexp for
            #   automatic-based named patterns
            # @param regexp [Regexp, nil] nil if we use auto-generated name based on the regexp or
            #   the regexp if we used named patterns
            # @param block [Proc] appropriate underlying topic settings
            def pattern=(regexp_or_name, regexp = nil, &block)
              # This code allows us to have a nice nameless (automatic-named) patterns that do not
              # have to be explicitly named. However if someone wants to use names for exclusions
              # it can be done by providing both
              if regexp_or_name.is_a?(Regexp)
                name = nil
                regexp = regexp_or_name
              else
                name = regexp_or_name
              end

              pattern = Pattern.new(name, regexp, block)
              virtual_topic = public_send(:topic=, pattern.name, &block)
              # Indicate the nature of this topic (matcher)
              virtual_topic.patterns(active: true, type: :matcher, pattern: pattern)
              # Pattern subscriptions should never be part of declarative topics definitions
              # Since they are subscribed by regular expressions, we do not know the target
              # topics names so we cannot manage them via declaratives
              virtual_topic.config(active: false)
              pattern.topic = virtual_topic
              @patterns << pattern
            end

            # @return [Hash] consumer group with patterns injected
            def to_h
              super.merge(
                patterns: patterns.map(&:to_h)
              ).freeze
            end
          end
        end
      end
    end
  end
end
