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

      private_constant :USED_LOG_LEVELS

      # Logs each messages fetching attempt
      #
      # @param event [Karafka::Core::Monitoring::Event] event details including payload
      def on_connection_listener_fetch_loop(event)
        listener = event[:caller]
        debug "[#{listener.id}] Polling messages..."
      end

      # Logs about messages that we've received from Kafka
      #
      # @param event [Karafka::Core::Monitoring::Event] event details including payload
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
      # @param event [Karafka::Core::Monitoring::Event] event details including payload
      def on_worker_process(event)
        job = event[:job]
        job_type = job.class.to_s.split('::').last
        consumer = job.executor.topic.consumer
        topic = job.executor.topic.name
        info "[#{job.id}] #{job_type} job for #{consumer} on #{topic} started"
      end

      # Prints info about the fact that a given job has finished
      #
      # @param event [Karafka::Core::Monitoring::Event] event details including payload
      def on_worker_processed(event)
        job = event[:job]
        time = event[:time]
        job_type = job.class.to_s.split('::').last
        consumer = job.executor.topic.consumer
        topic = job.executor.topic.name
        info "[#{job.id}] #{job_type} job for #{consumer} on #{topic} finished in #{time}ms"
      end

      # Prints info about a pause occurrence. Irrelevant if user or system initiated.
      #
      # @param event [Karafka::Core::Monitoring::Event] event details including payload
      def on_consumer_consuming_pause(event)
        topic = event[:topic]
        partition = event[:partition]
        offset = event[:offset]
        consumer = event[:caller]
        timeout = event[:timeout]

        info <<~MSG.tr("\n", ' ').strip!
          [#{consumer.id}] Pausing partition #{partition} of topic #{topic}
          on offset #{offset} for #{timeout} ms.
        MSG
      end

      # Prints info about retry of processing after an error
      #
      # @param event [Karafka::Core::Monitoring::Event] event details including payload
      def on_consumer_consuming_retry(event)
        topic = event[:topic]
        partition = event[:partition]
        offset = event[:offset]
        consumer = event[:caller]
        timeout = event[:timeout]

        info <<~MSG.tr("\n", ' ').strip!
          [#{consumer.id}] Retrying of #{consumer.class} after #{timeout} ms
          on partition #{partition} of topic #{topic} from offset #{offset}
        MSG
      end

      # Logs info about system signals that Karafka received and prints backtrace for threads in
      # case of ttin
      #
      # @param event [Karafka::Core::Monitoring::Event] event details including payload
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

      # Logs info that we're running Karafka app.
      #
      # @param _event [Karafka::Core::Monitoring::Event] event details including payload
      def on_app_running(_event)
        info "Running in #{RUBY_DESCRIPTION}"
        info "Running Karafka #{Karafka::VERSION} server"

        return if Karafka.pro?

        info 'See LICENSE and the LGPL-3.0 for licensing details.'
      end

      # @param _event [Karafka::Core::Monitoring::Event] event details including payload
      def on_app_quieting(_event)
        info 'Switching to quiet mode. New messages will not be processed.'
      end

      # Logs info that we're going to stop the Karafka server.
      #
      # @param _event [Karafka::Core::Monitoring::Event] event details including payload
      def on_app_stopping(_event)
        info 'Stopping Karafka server'
      end

      # Logs info that we stopped the Karafka server.
      #
      # @param _event [Karafka::Core::Monitoring::Event] event details including payload
      def on_app_stopped(_event)
        info 'Stopped Karafka server'
      end

      # Logs info when we have dispatched a message the the DLQ
      #
      # @param event [Karafka::Core::Monitoring::Event] event details including payload
      def on_dead_letter_queue_dispatched(event)
        message = event[:message]
        offset = message.offset
        topic = event[:caller].topic.name
        dlq_topic = event[:caller].topic.dead_letter_queue.topic
        partition = message.partition

        info "Dispatched message #{offset} from #{topic}/#{partition} to DLQ topic: #{dlq_topic}"
      end

      # There are many types of errors that can occur in many places, but we provide a single
      # handler for all of them to simplify error instrumentation.
      # @param event [Karafka::Core::Monitoring::Event] event details including payload
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
        when 'consumer.before_enqueue.error'
          error "Consumer before enqueue failed due to an error: #{error}"
          error details
        when 'consumer.before_consume.error'
          error "Consumer before consume failed due to an error: #{error}"
          error details
        when 'consumer.after_consume.error'
          error "Consumer after consume failed due to an error: #{error}"
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
        when 'runner.call.error'
          fatal "Runner crashed due to an error: #{error}"
          fatal details
        when 'app.stopping.error'
          error 'Forceful Karafka server stop'
        when 'librdkafka.error'
          error "librdkafka internal error occurred: #{error}"
          error details
        # Those will only occur when retries in the client fail and when they did not stop after
        # back-offs
        when 'connection.client.poll.error'
          error "Data polling error occurred: #{error}"
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
