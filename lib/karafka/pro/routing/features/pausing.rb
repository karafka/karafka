# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        # Feature allowing for a per-route reconfiguration of the pausing strategy
        # It can be useful when different topics should have different backoff policies
        class Pausing < Base
        end
      end
    end
  end
end
