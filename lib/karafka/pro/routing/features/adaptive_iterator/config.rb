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
        class AdaptiveIterator < Base
          # Adaptive Iterator configuration
          Config = Struct.new(
            :active,
            :safety_margin,
            :marking_method,
            :clean_after_yielding,
            keyword_init: true
          ) do
            alias_method :active?, :active
            alias_method :clean_after_yielding?, :clean_after_yielding
          end
        end
      end
    end
  end
end
