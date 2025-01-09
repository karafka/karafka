# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        # Feature allowing to run consumer operations even when no data is present on periodic
        # interval.
        # This allows for advanced window-based operations regardless of income of new data and
        # other advanced cases where the consumer is needed even when no data is coming
        class PeriodicJob < Base
        end
      end
    end
  end
end
