# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
