# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Patterns < Base
          # Patterns feature topic extensions
          module Topic
            # @return [String] subscription name or the regexp string representing matching of
            #   new topics that should be detected.
            def subscription_name
              patterns.active? && patterns.matcher? ? patterns.pattern.regexp_string : super
            end

            # @param active [Boolean] is this topic active member of patterns
            # @param type [Symbol] type of topic taking part in pattern matching
            # @param pattern [Regexp] regular expression for matching
            def patterns(active: false, type: :regular, pattern: nil)
              @patterns ||= Config.new(active: active, type: type, pattern: pattern)
            end

            # @return [Boolean] is this topic a member of patterns
            def patterns?
              patterns.active?
            end

            # @return [Hash] topic with all its native configuration options plus patterns
            def to_h
              super.merge(
                patterns: patterns.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
