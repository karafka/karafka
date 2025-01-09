# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    # Pro components related to processing part of Karafka
    module Processing
      # Pro jobs
      module Jobs
        # The revoked job type in a non-blocking variant.
        # This variant works "like" the regular revoked but does not block the queue.
        #
        # It can be useful when having long lasting jobs that would exceed `max.poll.interval`
        # in scenarios where there are more jobs than threads, without this being async we
        # would potentially stop polling
        class RevokedNonBlocking < ::Karafka::Processing::Jobs::Revoked
          self.action = :revoked

          # Makes this job non-blocking from the start
          # @param args [Array] any arguments accepted by `::Karafka::Processing::Jobs::Revoked`
          def initialize(*args)
            super
            @non_blocking = true
          end
        end
      end
    end
  end
end
