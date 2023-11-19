# frozen_string_literal: true

module Karafka
  module Processing
    # A simple object that allows us to keep track of processing state.
    # It allows to indicate if given thing moved from success to a failure or the other way around
    # Useful for tracking consumption state
    class Result
      attr_reader :cause

      def initialize
        @success = true
        @cause = false
      end

      # @return [Boolean]
      def success?
        @success
      end

      # Marks state as successful
      def success!
        @success = true
        # We set cause to false so the previous error that occurred does not leak when error is
        # no longer present
        @cause = false
      end

      # Marks state as failure
      # @param cause [StandardError] error that occurred and caused failure
      def failure!(cause)
        @success = false
        @cause = cause
      end

      # @return [Boolean] true if processing failed
      def failure?
        !@success
      end
    end
  end
end
