# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Default listener that hooks up to our instrumentation and uses its events for logging
    # It can be removed/replaced or anything without any harm to the Karafka app flow
    class StdoutListener
      # Log levels that we use in this particular listener
      USED_LOG_LEVELS = %i[
        debug
        info
        error
        fatal
      ].freeze

      # Logs details about incoming batches and with which consumer we will consume them
      # @param event [Dry::Events::Event] event details including payload
      def on_connection_batch_delegator_call(event)
        consumer = event[:consumer]
        topic = consumer.topic.name
        kafka_messages = event[:kafka_batch].messages
        info(
          <<~MSG.chomp.tr("\n", ' ')
            #{kafka_messages.count} messages
            on #{topic} topic
            delegated to #{consumer.class}
          MSG
        )
      end

      # Logs details about incoming message and with which consumer we will consume it
      # @param event [Dry::Events::Event] event details including payload
      def on_connection_message_delegator_call(event)
        consumer = event[:consumer]
        topic = consumer.topic.name
        info "1 message on #{topic} topic delegated to #{consumer.class}"
      end

      # Logs details about each received message value deserialization
      # @param event [Dry::Events::Event] event details including payload
      def on_params_params_deserialize(event)
        # Keep in mind, that a caller here is a param object not a controller,
        # so it returns a topic as a string, not a routing topic
        debug(
          <<~MSG.chomp.tr("\n", ' ')
            Params deserialization for #{event[:caller].metadata.topic} topic
            successful in #{event[:time]} ms
          MSG
        )
      end

      # Logs unsuccessful deserialization attempts of incoming data
      # @param event [Dry::Events::Event] event details including payload
      def on_params_params_deserialize_error(event)
        topic = event[:caller].metadata.topic
        error = event[:error]
        error "Params deserialization error for #{topic} topic: #{error}"
      end

      # Logs errors that occurred in a listener fetch loop
      # @param event [Dry::Events::Event] event details including payload
      # @note It's an error as we can recover from it not a fatal
      def on_connection_listener_fetch_loop_error(event)
        error "Listener fetch loop error: #{event[:error]}"
      end

      # Logs errors that are related to the connection itself
      # @param event [Dry::Events::Event] event details including payload
      # @note Karafka will attempt to reconnect, so an error not a fatal
      def on_connection_client_fetch_loop_error(event)
        error "Client fetch loop error: #{event[:error]}"
      end

      # Logs info about crashed fetcher
      # @param event [Dry::Events::Event] event details including payload
      # @note If this happens, Karafka will shutdown as it means a critical error
      #   in one of the threads
      def on_fetcher_call_error(event)
        fatal "Fetcher crash due to an error: #{event[:error]}"
      end

      # Logs info about processing of a certain dataset with an inline backend
      # @param event [Dry::Events::Event] event details including payload
      def on_backends_inline_process(event)
        count = event[:caller].send(:params_batch).to_a.size
        topic = event[:caller].topic.name
        time = event[:time]
        info "Inline processing of topic #{topic} with #{count} messages took #{time} ms"
      end

      # Logs info about system signals that Karafka received
      # @param event [Dry::Events::Event] event details including payload
      def on_process_notice_signal(event)
        info "Received #{event[:signal]} system signal"
      end

      # Logs info about responder usage withing a controller flow
      # @param event [Dry::Events::Event] event details including payload
      def on_consumers_responders_respond_with(event)
        calling = event[:caller]
        responder = calling.topic.responder
        data = event[:data]
        info "Responded from #{calling.class} using #{responder} with following data #{data}"
      end

      # Logs info that we're initializing Karafka app
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_initializing(_event)
        info "Initializing Karafka server #{::Process.pid}"
      end

      # Logs info that we're running Karafka app
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_running(_event)
        info "Running Karafka server #{::Process.pid}"
      end

      # Logs info that we're going to stop the Karafka server
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_stopping(_event)
        # We use a separate thread as logging can't be called from trap context
        Thread.new { info "Stopping Karafka server #{::Process.pid}" }
      end

      # Logs an error that Karafka was unable to stop the server gracefully and it had to do a
      #   forced exit
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
