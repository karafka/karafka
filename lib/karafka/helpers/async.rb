# frozen_string_literal: true

module Karafka
  module Helpers
    # Allows a given class to run async in a separate thread. Provides also few methods we may
    # want to use to control the underlying thread
    #
    # @note Thread running code needs to manage it's own exceptions. If they leak out, they will
    #   abort thread on exception.
    module Async
      class << self
        # Adds forwardable to redirect thread-based control methods to the underlying thread that
        # runs the async operations
        #
        # @param base [Class] class we're including this module in
        def included(base)
          base.extend ::Forwardable

          base.def_delegators :@thread, :join, :terminate, :alive?
        end
      end

      # Runs the `#call` method in a new thread
      def async_call
        @thread = Thread.new do
          Thread.current.abort_on_exception = true

          call
        end
      end
    end
  end
end
