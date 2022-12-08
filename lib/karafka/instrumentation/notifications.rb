# frozen_string_literal: true

module Karafka
  # Namespace for all the things related with Karafka instrumentation process
  module Instrumentation
    # Monitor is used to hookup external monitoring services to monitor how Karafka works
    # It provides a standardized API for checking incoming messages/enqueueing etc
    # Since it is a pub-sub based on dry-monitor, you can use as many subscribers/loggers at the
    # same time, which means that you might have for example file logging and NewRelic at the same
    # time
    # @note This class acts as a singleton because we are only permitted to have single monitor
    #   per running process (just as logger)
    class Notifications < Karafka::Core::Monitoring::Notifications
      # List of events that we support in the system and to which a monitor client can hook up
      # @note The non-error once support timestamp benchmarking
      # @note Depending on Karafka extensions and additional engines, this might not be the
      #   complete list of all the events. Please use the #available_events on fully loaded
      #   Karafka system to determine all of the events you can use.
      EVENTS = %w[
        app.initialized
        app.running
        app.quieting
        app.stopping
        app.stopped

        consumer.consumed
        consumer.consuming.pause
        consumer.consuming.retry
        consumer.revoked
        consumer.shutdown

        process.notice_signal

        connection.listener.before_fetch_loop
        connection.listener.fetch_loop
        connection.listener.fetch_loop.received

        dead_letter_queue.dispatched

        worker.process
        worker.processed
        worker.completed

        statistics.emitted

        error.occurred
      ].freeze

      private_constant :EVENTS

      # @return [Karafka::Instrumentation::Monitor] monitor instance for system instrumentation
      def initialize
        super
        EVENTS.each { |event| register_event(event) }
      end
    end
  end
end
