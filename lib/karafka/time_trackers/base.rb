# frozen_string_literal: true

module Karafka
  # Time trackers module.
  #
  # Time trackers are used to track time in context of having a time poll (amount of time
  # available for processing) or a pausing engine (pause for a time period).
  module TimeTrackers
    # Base class for all the time-trackers.
    class Base
      private

      # @return [Float] current time in milliseconds
      def now
        ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) * 1000
      end
    end
  end
end
