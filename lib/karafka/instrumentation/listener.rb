# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Default listener that hooks up to our instrumentation and uses its events for logging
    class Listener
      def self.on_params_params_parse(event)
        topic = event[:caller].topic
        time = event[:time]
        Karafka.logger.debug "Params parsing for #{topic} successful in #{time} ms"
      end

      def self.on_params_params_parse_error(event)
        topic = event[:caller].topic
        Karafka.logger.error "Params parsing error for #{topic}: #{event[:error]}"
      end

      def self.on_connection_listener_fetch_loop_error(event)
        Karafka.logger.error "Listener fetch loop error: #{event[:error]}"
      end

      def self.on_connection_client_fetch_loop_error(event)
        Karafka.logger.error "Client fetch loop error: #{event[:error]}"
      end

      def self.on_fetcher_call_error(event)
        Karafka.logger.fatal "Fetcher crash due to an error: #{event[:error]}"
      end

      def self.on_backends_inline_call(event)
        count = event[:caller].send(:params_batch).to_a.count
        topic = event[:caller].topic.name
        time = event[:time]
        Karafka.logger.info "Inline processing of #{topic} topic with #{count} messages took #{time} ms"
      end

      def self.on_process_notice_signal(event)
        Karafka.logger.info "Karafka received #{event[:signal]} system signal"
      end

      def self.on_consumers_responders_respond_with(event)
   #     Karafka.logger.info "Params parsing for #{topic} successful in #{time} ms"
      end
    end
  end
end
