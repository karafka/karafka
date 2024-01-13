# frozen_string_literal: true

module Karafka
  module Connection
    # Conductor is responsible for time orchestration of listeners manager.
    # It blocks when manager is not needed as there were no state changes that could cause any
    # listeners config changes and unblocks when things change or when certain time passed.
    # The time based unblocking allows for building of complex managers that could be state aware
    class Conductor
      # @param max_interval [Integer] after how many milliseconds of doing nothing should we wake
      #   up the manager despite no state changes
      def initialize(max_interval = 30_000)
        @lock = RUBY_VERSION < '3.2' ? Processing::TimedQueue.new : Queue.new
        @timeout = max_interval / 1_000.0
      end

      # Waits in a blocking way until it is time to manage listeners
      def wait
        @lock.pop(timeout: @timeout)
      end

      # Releases wait lock on state change
      def signal
        @lock << true
      end
    end
  end
end
