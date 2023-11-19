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
