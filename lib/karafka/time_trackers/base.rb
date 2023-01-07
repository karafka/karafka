# frozen_string_literal: true

module Karafka
  # Time trackers module.
  #
  # Time trackers are used to track time in context of having a time poll (amount of time
  # available for processing) or a pausing engine (pause for a time period).
  module TimeTrackers
    # Base class for all the time-trackers.
    class Base
      include ::Karafka::Core::Helpers::Time
    end
  end
end
