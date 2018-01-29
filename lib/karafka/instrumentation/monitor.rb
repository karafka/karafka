# frozen_string_literal: true

module Karafka
  # Namespace for all the things related with Karafka instrumentation process
  module Instrumentation
    # Monitor is used to hookup external monitoring services to monitor how Karafka works
    # It provides a standardized API for checking incoming messages/enqueueing etc
    # Since it is a pub-sub based on dry-monitor, you can use as many subscribers/loggers at the
    # same time, which means that you might have for example file logging and newrelic at the same
    # time
    # @note This class acts as a singleton because we are only permitted to have single monitor
    #   per running process (just as logger)
    class Monitor < Dry::Monitor::Notifications
      include Singleton

      # List of events that we support in the system and to which a monitor client can hook up
      # @note The non-error once support timestamp benchmarking
      # @note Depending on Karafka extensions and additional engines, this might not be the
      #   complete list of all the events. Please use the #available_events on fully loaded
      #   Karafka system to determine all of the events you can use
      BASE_EVENTS = %w[
        params.params.parse
        params.params.parse_error
        connection.listener.fetch_loop_error
        connection.client.fetch_loop_error
        fetcher.call_error
        backends.inline.process
        process.notice_signal
        consumers.responders.respond_with
      ].freeze

      private_constant :BASE_EVENTS

      # @return [Karafka::Monitor] monitor instance for system instrumentation
      def initialize
        super(:karafka)
        BASE_EVENTS.each(&method(:register_event))
      end

      # Allows us to subscribe to events with a code that will be yielded upon events
      # @param event_name_or_listener [String, Object] name of the event we want to subscribe to
      #   or a listener if we decide to go with object listener
      def subscribe(event_name_or_listener)
        return super unless event_name_or_listener.is_a?(String)
        return super if available_events.include?(event_name_or_listener)
        raise Errors::UnregisteredMonitorEvent, event_name_or_listener
      end

      # @return [Array<String>] names of available events to which we can subscribe
      def available_events
        __bus__.events.keys
      end
    end
  end
end
