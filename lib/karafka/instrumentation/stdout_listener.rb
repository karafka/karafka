# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Default listener that hooks up to our instrumentation and uses its events for logging
    # It can be removed/replaced or anything without any harm to the Karafka app flow.
    class StdoutListener
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

      # Logs errors that occurred in a listener fetch loop.
      #
      # @param event [Dry::Events::Event] event details including payload
      # @note It's an error as we can recover from it not a fatal
      def on_connection_listener_fetch_loop_error(event)
        error "Listener fetch loop error: #{event[:error]}"
        error (event[:error].backtrace || []).join("\n")
      end

      # Logs info about crashed runner.
      #
      # @param event [Dry::Events::Event] event details including payload
      # @note If this happens, Karafka will shutdown as it means a critical error
      #   in one of the threads
      def on_runner_call_error(event)
        fatal "Runner crash due to an error: #{event[:error]}"
      end

      # Logs details about crash that happened during consumption
      #
      # @param event [Dry::Events::Event] event details including payload
      def on_consumer_consume_error(event)
        error "Consuming failed due to an error: #{event[:error]}"
        error (event[:error].backtrace || []).join("\n")
      end

      # Logs details about crash that happened during consumer revoking
      #
      # @param event [Dry::Events::Event] event details including payload
      def on_consumer_revoked_error(event)
        error "Revoking failed due to an error: #{event[:error]}"
        error (event[:error].backtrace || []).join("\n")
      end

      # Logs details about crash that happened during consumer shutdown
      #
      # @param event [Dry::Events::Event] event details including payload
      def on_consumer_shutdown_error(event)
        error "Shutting down failed due to an error: #{event[:error]}"
        error (event[:error].backtrace || []).join("\n")
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

      # Logs an error that Karafka was unable to stop the server gracefully and it had to do a
      #   forced exit.
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_stopping_error(_event)
        # We use a separate thread as logging can't be called from trap context
        Thread.new { error 'Forceful Karafka server stop' }
      end

      # Logs that there has been an exception in the worker
      #
      # @param event [Dry::Events::Event] event details including payload
      def on_worker_process_error(event)
        fatal "Worker processing failed due to an error: #{event[:error]}"
        fatal (event[:error].backtrace || []).join("\n")
      end

      # Logs info about error that happened in a consumer background thread
      #
      # @param event [Dry::Events::Event] event details including payload
      def on_emitted_error(event)
        error "Background thread error emitted: #{event[:error]}"
      end

      USED_LOG_LEVELS.each do |log_level|
        define_method log_level do |*args|
          Karafka.logger.send(log_level, *args)
        end
      end
    end
  end
end
