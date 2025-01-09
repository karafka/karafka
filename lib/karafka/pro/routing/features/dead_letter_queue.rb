# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        # Enhanced Dead Letter Queue
        #
        # This version behaves similar to the regular version but provides ordering warranties and
        # allows for batch skipping
        class DeadLetterQueue < Base
        end
      end
    end
  end
end
