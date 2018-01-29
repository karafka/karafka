# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Default listener that hooks up to our instrumentation and uses its events for logging
    # It can be removed/replaced or anything without any harm to the Karafka app flow
    class Listener
      class << self
        # Logs details about each received message value parsing
        # @param event [Dry::Events::Event] event details including payload
        def on_params_params_parse(event)
          # Keep in mind, that a caller here is a param object not a controller,
          # so it returns a topic as a string, not a routing topic
          debug "Params parsing for #{event[:caller].topic} topic successful in #{event[:time]} ms"
        end

        # Logs unsuccessful parsing attempts of incoming data
        # @param event [Dry::Events::Event] event details including payload
        def on_params_params_parse_error(event)
          error "Params parsing error for #{event[:caller].topic} topic: #{event[:error]}"
        end

        # Logs errors that occured in a listener fetch loop
        # @param event [Dry::Events::Event] event details including payload
        # @note It's an error as we can recover from it not a fatal
        def on_connection_listener_fetch_loop_error(event)
          error "Listener fetch loop error: #{event[:error]}"
        end

        # Logs errors that are related to the connection itself
        # @note Karafka will attempt to reconnect, so an error not a fatal
        # @param event [Dry::Events::Event] event details including payload
        def on_connection_client_fetch_loop_error(event)
          error "Client fetch loop error: #{event[:error]}"
        end

        # Logs info about crashed fetcher
        # @note If this happens, Karafka will shutdown as it means a critical error
        #   in one of the threads
        # @param event [Dry::Events::Event] event details including payload
        def on_fetcher_call_error(event)
          fatal "Fetcher crash due to an error: #{event[:error]}"
        end

        # Logs info about processing of a certain dataset with an inline backend
        # @param event [Dry::Events::Event] event details including payload
        def on_backends_inline_process(event)
          count = event[:caller].send(:params_batch).to_a.size
          topic = event[:caller].topic.name
          time = event[:time]
          info "Inline processing of #{topic} topic with #{count} messages took #{time} ms"
        end

        # Logs info about system signals that Karafka received
        # @param event [Dry::Events::Event] event details including payload
        def on_process_notice_signal(event)
          info "Received #{event[:signal]} system signal"
        end

        # Logs info about responder usage withing a controller flow
        # @param event [Dry::Events::Event] event details including payload
        def on_consumers_responders_respond_with(event)
          calling = event[:caller].class
          responder = calling.topic.responder
          data = event[:data]
          info "Responded from #{calling} using #{responder} with following data #{data}"
        end

        private

        %i[
          debug
          info
          error
          fatal
        ].each do |log_method|
          define_method log_method do |*args|
            Karafka.logger.send(log_method, *args)
          end
        end
      end
    end
  end
end
