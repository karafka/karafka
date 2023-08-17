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
            # @param regexp [Regexp] regular expression that should match newly discovered topics
            # @param block [Proc] appropriate underlying topic settings
            def pattern=(regexp, &block)
              pattern = Pattern.new(regexp, block)
              virtual_topic = public_send(:topic=, pattern.topic_name, &block)
              # Indicate the nature of this topic (placeholder)
              virtual_topic.patterns(true, :placeholder)
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
