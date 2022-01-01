# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Default listener that hooks up to our instrumentation and uses its events for logging
    # It can be removed/replaced or anything without any harm to the Karafka app flow.
    class LoggerListener
      # Log levels that we use in this particular listener
      USED_LOG_LEVELS = %i[
        debug
        info
        error
        fatal
      ].freeze

      # Logs each messages fetching attempt
      #
      # @param _event [Dry::Events::Event] event details including payload
      def on_connection_listener_fetch_loop(_event)
        info 'Receiving new messages from Kafka...'
      end

      # Logs about messages that we've received from Kafka
      #
      # @param event [Dry::Events::Event] event details including payload
      def on_connection_listener_fetch_loop_received(event)
        info "Received #{event[:messages_buffer].size} new messages from Kafka"
      end

      # Logs info about system signals that Karafka received.
      #
      # @param event [Dry::Events::Event] event details including payload
      def on_process_notice_signal(event)
        info "Received #{event[:signal]} system signal"
      end

      # Logs info that we're initializing Karafka app.
      #
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_initializing(_event)
        info 'Initializing Karafka framework'
      end

      # Logs info that we're running Karafka app.
      #
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_running(_event)
        info 'Running Karafka server'
      end

      # Logs info that we're going to stop the Karafka server.
      #
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_stopping(_event)
        # We use a separate thread as logging can't be called from trap context
        Thread.new { info 'Stopping Karafka server' }
      end

      # Logs info that we stopped the Karafka server.
      #
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_stopped(_event)
        # We use a separate thread as logging can't be called from trap context
        Thread.new { info 'Stopped Karafka server' }
      end

      # There are many types of errors that can occur in many places, but we provide a single
      # handler for all of them to simplify error instrumentation.
      # @param event [Dry::Events::Event] event details including payload
      def on_error_occurred(event)
        type = event[:type]
        error = event[:error]
        details = (error.backtrace || []).join("\n")

        case type
        when 'consumer.consume.error'
          error "Consumer consuming error: #{error}"
          error details
        when 'consumer.revoked.error'
          error "Consumer on revoked failed due to an error: #{error}"
          error details
        when 'consumer.shutdown.error'
          error "Consumer on shutdown failed due to an error: #{error}"
          error details
        when 'worker.process.error'
          fatal "Worker processing failed due to an error: #{error}"
          fatal details
        when 'connection.listener.fetch_loop.error'
          error "Listener fetch loop error: #{error}"
          error details
        when 'licenser.expired'
          error error
          error details
        when 'runner.call.error'
          fatal "Runner crashed due to an error: #{error}"
          fatal details
        when 'app.stopping.error'
          # We use a separate thread as logging can't be called from trap context
          Thread.new { error 'Forceful Karafka server stop' }
        when 'librdkafka.error'
          error "librdkafka internal error occurred: #{error}"
          error details
        else
          # This should never happen. Please contact the maintainers
          raise Errors::UnsupportedCaseError, event
        end
      end

      USED_LOG_LEVELS.each do |log_level|
        define_method log_level do |*args|
          Karafka.logger.send(log_level, *args)
        end
      end
    end
  end
end
