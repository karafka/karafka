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
        warn
        error
        fatal
      ].freeze

      # Logs each messages fetching attempt
      #
      # @param event [Dry::Events::Event] event details including payload
      def on_connection_listener_fetch_loop(event)
        listener = event[:caller]
        debug "[#{listener.id}] Polling messages..."
      end

      # Logs about messages that we've received from Kafka
      #
      # @param event [Dry::Events::Event] event details including payload
      def on_connection_listener_fetch_loop_received(event)
        listener = event[:caller]
        time = event[:time]
        messages_count = event[:messages_buffer].size

        message = "[#{listener.id}] Polled #{messages_count} messages in #{time}ms"

        # We don't want the "polled 0" in dev as it would spam the log
        # Instead we publish only info when there was anything we could poll and fail over to the
        # zero notifications when in debug mode
        messages_count.zero? ? debug(message) : info(message)
      end

      # Prints info about the fact that a given job has started
      #
      # @param event [Dry::Events::Event] event details including payload
      def on_worker_process(event)
        job = event[:job]
        job_type = job.class.to_s.split('::').last
        consumer = job.executor.topic.consumer
        topic = job.executor.topic.name
        info "[#{job.id}] #{job_type} job for #{consumer} on #{topic} started"
      end

      # Prints info about the fact that a given job has finished
      #
      # @param event [Dry::Events::Event] event details including payload
      def on_worker_processed(event)
        job = event[:job]
        time = event[:time]
        job_type = job.class.to_s.split('::').last
        consumer = job.executor.topic.consumer
        topic = job.executor.topic.name
        info "[#{job.id}] #{job_type} job for #{consumer} on #{topic} finished in #{time}ms"
      end

      # Logs info about system signals that Karafka received and prints backtrace for threads in
      # case of ttin
      #
      # @param event [Dry::Events::Event] event details including payload
      def on_process_notice_signal(event)
        info "Received #{event[:signal]} system signal"

        # We print backtrace only for ttin
        return unless event[:signal] == :SIGTTIN

        # Inspired by Sidekiq
        Thread.list.each do |thread|
          tid = (thread.object_id ^ ::Process.pid).to_s(36)

          warn "Thread TID-#{tid} #{thread['label']}"

          if thread.backtrace
            warn thread.backtrace.join("\n")
          else
            warn '<no backtrace available>'
          end
        end
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
        info "Running in #{RUBY_DESCRIPTION}"
        info "Running Karafka #{Karafka::VERSION} server"

        return if Karafka.pro?

        info 'See LICENSE and the LGPL-3.0 for licensing details.'
      end

      # Logs info that we're going to stop the Karafka server.
      #
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_stopping(_event)
        info 'Stopping Karafka server'
      end

      # Logs info that we stopped the Karafka server.
      #
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_stopped(_event)
        info 'Stopped Karafka server'
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
          error 'Forceful Karafka server stop'
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
