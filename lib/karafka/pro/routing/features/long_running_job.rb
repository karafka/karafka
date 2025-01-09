# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    # Namespace for Pro routing enhancements
    module Routing
      # Namespace for additional Pro features
      module Features
        # Long-Running Jobs feature config and DSL namespace.
        #
        # Long-Running Jobs allow you to run Karafka jobs beyond `max.poll.interval.ms`
        class LongRunningJob < Base
        end
      end
    end
  end
end
