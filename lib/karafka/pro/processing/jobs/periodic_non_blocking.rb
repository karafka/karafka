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
    module Processing
      module Jobs
        # Non-Blocking version of the Periodic job
        # We use this version for LRJ topics for cases where saturated resources would not allow
        # to run this job for extended period of time. Under such scenarios, if we would not use
        # a non-blocking one, we would reach max.poll.interval.ms.
        class PeriodicNonBlocking < Periodic
          # @param args [Array] any arguments accepted by `::Karafka::Processing::Jobs::Periodic`
          def initialize(*args)
            super
            @non_blocking = true
          end
        end
      end
    end
  end
end
