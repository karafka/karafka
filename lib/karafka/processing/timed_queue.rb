# frozen_string_literal: true

module Karafka
  module Processing
    # Minimal queue with timeout for Ruby 3.1 and lower.
    #
    # It is needed because only since 3.2, Ruby has a timeout on `#pop`
    class TimedQueue
      include Karafka::Core::Helpers::Time

      def initialize
        @queue = Queue.new
        @mutex = Thread::Mutex.new
        @resource = Thread::ConditionVariable.new
      end

      # Adds element to the queue
      #
      # @param obj [Object] pushes an element onto the queue
      def push(obj)
        @mutex.synchronize do
          @queue << obj
          @resource.broadcast
        end
      end

      alias << push

      # No timeout means waiting up to 31 years
      #
      # @param timeout [Integer] max number of seconds to wait on the pop
      # @return [Object] element inserted on the array or `nil` on timeout
      #
      # @note We use timeout in seconds because this is how Ruby 3.2+ works and we want to have
      #   the same API for newer and older Ruby versions
      def pop(timeout: 10_000_000_000)
        deadline = monotonic_now + timeout * 1000

        @mutex.synchronize do
          loop do
            return @queue.pop unless @queue.empty?
            return @queue.pop if @queue.closed?

            to_wait = (deadline - monotonic_now) / 1_000.0

            return nil if to_wait <= 0

            @resource.wait(@mutex, to_wait)
          end
        end
      end

      # Closes the internal queue and releases the lock
      def close
        @mutex.synchronize do
          @queue.close
          @resource.broadcast
        end
      end
    end
  end
end
