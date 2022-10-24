# frozen_string_literal: true

# A karafka's logger listener for Datadog
# It depends on the 'ddtrace' gem
class LoggerListener
  LOG_LEVELS = %i[info error fatal].freeze

  # Prints info about the fact that a given job has started
  #
  # @param event [Dry::Events::Event] event details including payload
  def on_worker_process(event)
    current_span = Datadog::Tracing.trace('karafka.consumer')
    Karafka.logger.push_tags(Datadog::Tracing.log_correlation) if Karafka.logger.respond_to?(:push_tags)

    job = event[:job]
    job_type = job.class.to_s.split('::').last
    consumer = job.executor.topic.consumer
    topic = job.executor.topic.name

    current_span.resource = "#{consumer}#consume"
    info "[#{job.id}] #{job_type} job for #{consumer} on #{topic} started"

    Karafka.logger.pop_tags if Karafka.logger.respond_to?(:pop_tags)
  end

  # Prints info about the fact that a given job has finished
  #
  # @param event [Dry::Events::Event] event details including payload
  def on_worker_processed(event)
    Karafka.logger.push_tags(Datadog::Tracing.log_correlation) if Karafka.logger.respond_to?(:push_tags)

    job = event[:job]
    time = event[:time]
    job_type = job.class.to_s.split('::').last
    consumer = job.executor.topic.consumer
    topic = job.executor.topic.name

    info "[#{job.id}] #{job_type} job for #{consumer} on #{topic} finished in #{time}ms"

    current_span = Datadog::Tracing.active_span
    current_span.finish if current_span.present?

    Karafka.logger.pop_tags if Karafka.logger.respond_to?(:pop_tags)
  end

  # There are many types of errors that can occur in many places, but we provide a single
  # handler for all of them to simplify error instrumentation.
  # @param event [Dry::Events::Event] event details including payload
  def on_error_occurred(event)
    Karafka.logger.push_tags(Datadog::Tracing.log_correlation) if Karafka.logger.respond_to?(:push_tags)

    error = event[:error]
    Datadog::Tracing.active_span&.set_error(error)

    case event[:type]
    when 'consumer.consume.error'
      error "Consumer consuming error: #{error}"
    when 'consumer.revoked.error'
      error "Consumer on revoked failed due to an error: #{error}"
    when 'consumer.shutdown.error'
      error "Consumer on shutdown failed due to an error: #{error}"
    when 'worker.process.error'
      fatal "Worker processing failed due to an error: #{error}"
    when 'connection.listener.fetch_loop.error'
      error "Listener fetch loop error: #{error}"
    when 'licenser.expired'
      error error
    when 'runner.call.error'
      fatal "Runner crashed due to an error: #{error}"
    when 'app.stopping.error'
      error 'Forceful Karafka server stop'
    when 'librdkafka.error'
      error "librdkafka internal error occurred: #{error}"
      # Those will only occur when retries in the client fail and when they did not stop after
      # backoffs
    when 'connection.client.poll.error'
      error "Data polling error occurred: #{error}"
    else
      Karafka.logger.pop_tags if Karafka.logger.respond_to?(:pop_tags)
      # This should never happen. Please contact the maintainers
      raise Errors::UnsupportedCaseError, event
    end

    Karafka.logger.pop_tags if Karafka.logger.respond_to?(:pop_tags)
  end

  LOG_LEVELS.each do |log_level|
    define_method log_level do |*args|
      Karafka.logger.send(log_level, *args)
    end
  end
end
