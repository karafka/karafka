# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    # Namespace for Pro routing enhancements
    module Routing
      # Namespace for additional Pro features
      module Features
        # Non Blocking Job is just an alias for LRJ.
        #
        # We however have it as a separate feature because its use-case may vary from LRJ.
        #
        # While LRJ is used mainly for long-running jobs that would take more than max poll
        # interval time, non-blocking can be applied to make sure that we do not wait with polling
        # of different partitions and topics that are subscribed together.
        #
        # This effectively allows for better resources utilization
        #
        # All the underlying code is the same but use-case is different and this should be
        # reflected in the routing, hence this "virtual" feature.
        class NonBlockingJob < Base
        end
      end
    end
  end
end
