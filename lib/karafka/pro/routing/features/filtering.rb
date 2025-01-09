# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        # Filtering provides a generic API allowing you to pre-filter messages before they are
        # dispatched to jobs and processed.
        #
        # It allows for throttling, delayed jobs and other filtering implementations.
        class Filtering < Base
        end
      end
    end
  end
end
