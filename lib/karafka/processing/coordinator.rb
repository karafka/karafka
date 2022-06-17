# frozen_string_literal: true

module Karafka
  module Processing
    # Basic coordinator that allows us to provide coordination objects into consumers.
    # This is a wrapping layer to simplify management of work to be handled.
    class Coordinator
      # @return [Karafka::TimeTrackers::Pause]
      attr_reader :pause_tracker

      # @param pause_tracker [Karafka::TimeTrackers::Pause] pause tracker for given topic partition
      def initialize(pause_tracker)
        @pause_tracker = pause_tracker
      end
    end
  end
end
