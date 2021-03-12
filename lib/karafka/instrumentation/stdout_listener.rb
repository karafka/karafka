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

      # Logs errors that occurred in a listener fetch loop.
      #
      # @param event [Dry::Events::Event] event details including payload
      # @note It's an error as we can recover from it not a fatal
      def on_connection_listener_fetch_loop_error(event)
        error "Listener fetch loop error: #{event[:error]}"
      end

      # Logs errors that are related to the connection itself.
      #
      # @param event [Dry::Events::Event] event details including payload
      # @note Karafka will attempt to reconnect, so an error not a fatal
      def on_connection_client_fetch_loop_error(event)
        error "Client fetch loop error: #{event[:error]}"
      end

      # Logs info about crashed runner.
      #
      # @param event [Dry::Events::Event] event details including payload
      # @note If this happens, Karafka will shutdown as it means a critical error
      #   in one of the threads
      def on_runner_call_error(event)
        fatal "Runner crash due to an error: #{event[:error]}"
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
        info "Initializing Karafka server #{::Process.pid}"
      end

      # Logs info that we're running Karafka app.
      #
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_running(_event)
        info "Running Karafka server #{::Process.pid}"
      end

      # Logs info that we're going to stop the Karafka server.
      #
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_stopping(_event)
        # We use a separate thread as logging can't be called from trap context
        Thread.new { info "Stopping Karafka server #{::Process.pid}" }
      end

      # Logs an error that Karafka was unable to stop the server gracefully and it had to do a
      #   forced exit.
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_stopping_error(_event)
        # We use a separate thread as logging can't be called from trap context
        Thread.new { error "Forceful Karafka server #{::Process.pid} stop" }
      end

      USED_LOG_LEVELS.each do |log_level|
        define_method log_level do |*args|
          Karafka.logger.send(log_level, *args)
        end
      end
    end
  end
end
