# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Namespace for vendor specific instrumentation
    module Vendors
      # Datadog specific instrumentation
      module Datadog
        # A karafka's logger listener for Datadog
        # It depends on the 'ddtrace' gem
        class LoggerListener
          include ::Karafka::Core::Configurable
          extend Forwardable

          def_delegators :config, :client, :service_name

          # `Datadog::Tracing` client that we should use to trace stuff
          setting :client

          # @see https://docs.datadoghq.com/tracing/trace_collection/dd_libraries/ruby
          setting :service_name, default: nil

          configure

          # Log levels that we use in this particular listener
          USED_LOG_LEVELS = %i[
            info
            error
            fatal
          ].freeze

          private_constant :USED_LOG_LEVELS

          # @param block [Proc] configuration block
          def initialize(&block)
            configure
            setup(&block) if block
            @job_types_cache = {}
          end

          # @param block [Proc] configuration block
          # @note We define this alias to be consistent with `WaterDrop#setup`
          def setup(&block)
            configure(&block)
          end

          # Prints info about the fact that a given job has started
          #
          # @param event [Karafka::Core::Monitoring::Event] event details including payload
          def on_worker_process(event)
            current_span = client.trace('karafka.consumer', service: service_name)
            push_tags

            job = event[:job]
            job_type = fetch_job_type(job.class)
            consumer = job.executor.topic.consumer
            topic = job.executor.topic.name

            current_span.resource = "#{consumer}##{job.class.action}"
            info "[#{job.id}] #{job_type} job for #{consumer} on #{topic} started"

            pop_tags
          end

          # Prints info about the fact that a given job has finished
          #
          # @param event [Karafka::Core::Monitoring::Event] event details including payload
          def on_worker_processed(event)
            push_tags

            job = event[:job]
            time = event[:time]
            job_type = job.class.to_s.split('::').last
            consumer = job.executor.topic.consumer
            topic = job.executor.topic.name

            info "[#{job.id}] #{job_type} job for #{consumer} on #{topic} finished in #{time}ms"

            client.active_span&.finish

            pop_tags
          end

          # There are many types of errors that can occur in many places, but we provide a single
          # handler for all of them to simplify error instrumentation.
          # @param event [Karafka::Core::Monitoring::Event] event details including payload
          def on_error_occurred(event)
            push_tags

            error = event[:error]
            client.active_span&.set_error(error)

            case event[:type]
            when 'consumer.consume.error'
              error "Consumer consuming error: #{error}"
            when 'consumer.revoked.error'
              error "Consumer on revoked failed due to an error: #{error}"
            when 'consumer.before_schedule.error'
              error "Consumer before schedule failed due to an error: #{error}"
            when 'consumer.before_consume.error'
              error "Consumer before consume failed due to an error: #{error}"
            when 'consumer.after_consume.error'
              error "Consumer after consume failed due to an error: #{error}"
            when 'consumer.shutdown.error'
              error "Consumer on shutdown failed due to an error: #{error}"
            when 'consumer.tick.error'
              error "Consumer tick failed due to an error: #{error}"
            when 'consumer.eofed.error'
              error "Consumer eofed failed due to an error: #{error}"
            when 'worker.process.error'
              fatal "Worker processing failed due to an error: #{error}"
            when 'connection.listener.fetch_loop.error'
              error "Listener fetch loop error: #{error}"
            when 'runner.call.error'
              fatal "Runner crashed due to an error: #{error}"
            when 'app.stopping.error'
              error 'Forceful Karafka server stop'
            when 'swarm.supervisor.error'
              fatal "Swarm supervisor crashed due to an error: #{error}"
            when 'librdkafka.error'
              error "librdkafka internal error occurred: #{error}"
              # Those will only occur when retries in the client fail and when they did not stop
              # after back-offs
            when 'connection.client.poll.error'
              error "Data polling error occurred: #{error}"
            else
              pop_tags
              # This should never happen. Please contact the maintainers
              raise Errors::UnsupportedCaseError, event
            end

            pop_tags
          end

          USED_LOG_LEVELS.each do |log_level|
            define_method log_level do |*args|
              Karafka.logger.send(log_level, *args)
            end
          end

          # Pushes datadog's tags to the logger
          # This is required when tracing log lines asynchronously to correlate logs of the same
          # process together
          def push_tags
            return unless Karafka.logger.respond_to?(:push_tags)

            Karafka.logger.push_tags(client.log_correlation)
          end

          # Pops datadog's tags from the logger
          # This is required when tracing log lines asynchronously to avoid the logs of the
          # different processes to be correlated
          def pop_tags
            return unless Karafka.logger.respond_to?(:pop_tags)

            Karafka.logger.pop_tags
          end

          private

          # Takes the job class and extracts the job type.
          # @param job_class [Class] job class
          # @return [String]
          # @note It does not have to be thread-safe despite running in multiple threads because
          #   the assignment race condition is irrelevant here since the same value will be
          #   assigned.
          def fetch_job_type(job_class)
            @job_types_cache[job_class] ||= job_class.to_s.split('::').last
          end
        end
      end
    end
  end
end
