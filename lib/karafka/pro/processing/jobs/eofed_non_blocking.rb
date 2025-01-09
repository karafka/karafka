# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Jobs
        # Non-Blocking version of the Eofed job
        # We use this version for LRJ topics for cases where saturated resources would not allow
        # to run this job for extended period of time. Under such scenarios, if we would not use
        # a non-blocking one, we would reach max.poll.interval.ms.
        class EofedNonBlocking < ::Karafka::Processing::Jobs::Eofed
          self.action = :eofed

          # @param args [Array] any arguments accepted by `::Karafka::Processing::Jobs::Eofed`
          def initialize(*args)
            super
            @non_blocking = true
          end
        end
      end
    end
  end
end
