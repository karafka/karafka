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
            # @param active [Boolean] is this topic active member of patterns
            # @param type [Symbol] is this a placeholder or discovered topic
            def patterns(active = false, type = :placeholder)
              @patterns ||= Config.new(active: active, type: type)
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
