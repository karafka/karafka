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
            def patterns(active: :not_given, type: :not_given, pattern: :not_given)
              @patterns ||= Config.new(active: false, type: :regular, pattern: nil)
              return @patterns if [active, type, pattern].uniq == [:not_given]

              @patterns.active = active unless active == :not_given
              @patterns.type = type unless type == :not_given
              @patterns.pattern = pattern unless pattern == :not_given
              @patterns
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
