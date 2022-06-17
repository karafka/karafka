# frozen_string_literal: true

module Karafka
  module Processing
    # A simple object that allows us to keep track of processing state.
    # It allows to indicate if given thing moved from success to a failure or the other way around
    # Useful for tracking consumption state
    class Result
      def initialize
        @success = true
      end

      # @return [Boolean]
      def failure?
        !success?
      end

      # @return [Boolean]
      def success?
        @success
      end

      # Marks state as successful
      def success!
        @success = true
      end

      # Marks state as failure
      def failure!
        @success = false
      end
    end
  end
end
