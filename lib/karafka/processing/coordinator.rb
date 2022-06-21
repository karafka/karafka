# frozen_string_literal: true

module Karafka
  module Processing
    # Basic coordinator that allows us to provide coordination objects into consumers.
    # This is a wrapping layer to simplify management of work to be handled.
    # @note This coordinator needs to be thread safe
    class Coordinator
      # @return [Karafka::TimeTrackers::Pause]
      attr_reader :pause_tracker

      # @param pause_tracker [Karafka::TimeTrackers::Pause] pause tracker for given topic partition
      def initialize(pause_tracker)
        @pause_tracker = pause_tracker
        @revoked = false
        @mutex = Mutex.new
      end

      # Marks given coordinator for consumer as revoked
      def revoke
        @mutex.synchronize do
          @revoke = true
        end
      end

      def revoked?
        @revoked
      end
    end
  end
end
