# frozen_string_literal: true

module Karafka
  module Helpers
    # Allows a given class to run async in a separate thread. Provides also few methods we may
    # want to use to control the underlying thread
    #
    # @note Thread running code needs to manage it's own exceptions. If they leak out, they will
    #   abort thread on exception.
    module Async
      # Mutex used to ensure we do not create multiple threads if we decide to run this
      # in parallel on multiple threads
      MUTEX = Mutex.new

      private_constant :MUTEX

      class << self
        # Adds forwardable to redirect thread-based control methods to the underlying thread that
        # runs the async operations
        #
        # @param base [Class] class we're including this module in
        def included(base)
          base.extend ::Forwardable

          base.def_delegators :@thread, :join, :terminate, :name
        end
      end

      # @return [Boolean] true if thread is present and is running, false otherwise
      def alive?
        MUTEX.synchronize do
          return false unless @thread

          @thread.alive?
        end
      end

      # Runs the `#call` method in a new thread
      # @param thread_name [String] name that we want to assign to the thread when we start it
      # @param thread_priority [Integer] Ruby thread priority
      def async_call(thread_name, thread_priority = 0)
        MUTEX.synchronize do
          return if @thread&.alive?

          @thread = Thread.new do
            Thread.current.name = thread_name
            Thread.current.priority = thread_priority

            Thread.current.abort_on_exception = true

            call
          end
        end
      end
    end
  end
end
