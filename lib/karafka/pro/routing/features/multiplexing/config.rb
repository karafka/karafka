# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Multiplexing < Base
          # Multiplexing configuration
          Config = Struct.new(
            :active,
            :min,
            :max,
            :boot,
            :scale_delay,
            keyword_init: true
          ) do
            alias_method :active?, :active

            # @return [Boolean] true if we are allowed to upscale and downscale
            def dynamic?
              min < max
            end
          end
        end
      end
    end
  end
end
