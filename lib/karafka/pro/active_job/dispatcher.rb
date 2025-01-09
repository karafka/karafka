# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    # Karafka Pro ActiveJob components
    module ActiveJob
      # Pro dispatcher that sends the ActiveJob job to a proper topic based on the queue name
      # and that allows to inject additional options into the producer, effectively allowing for a
      # much better and more granular control over the dispatch and consumption process.
      class Dispatcher < ::Karafka::ActiveJob::Dispatcher
        # Defaults for dispatching
        # They can be updated by using `#karafka_options` on the job
        DEFAULTS = {
          dispatch_method: :produce_async,
          dispatch_many_method: :produce_many_async,
          # We don't create a dummy proc based partitioner as we would have to evaluate it with
          # each job.
          partitioner: nil,
          # Allows for usage of `:key` or `:partition_key`
          partition_key_type: :key,
          # Topic to where this message should go when using scheduled messages. When defined,
          # it will be used with `enqueue_at`. If not defined it will raise an error.
          scheduled_messages_topic: nil,
          # Allows for setting a callable producer since at the moment of defining the class,
          # variants may not be available
          #
          # We do not initialize it with `-> { ::Karafka.producer }` so we do not have to call it
          #   each time for the defaults to preserve CPU cycles.
          #
          # We also do **not** cache the execution of this producer lambda because we want to
          # support job args based producer selection
          producer: nil
        }.freeze

        private_constant :DEFAULTS

        # @param job [ActiveJob::Base] job
        def dispatch(job)
          producer(job).public_send(
            fetch_option(job, :dispatch_method, DEFAULTS),
            dispatch_details(job).merge!(
              topic: job.queue_name,
              payload: ::ActiveSupport::JSON.encode(serialize_job(job))
            )
          )
        end

        # Bulk dispatches multiple jobs using the Rails 7.1+ API
        # @param jobs [Array<ActiveJob::Base>] jobs we want to dispatch
        def dispatch_many(jobs)
          # First level is type of dispatch and second is the producer we want to use to dispatch
          dispatches = Hash.new do |hash, key|
            hash[key] = Hash.new do |hash2, key2|
              hash2[key2] = []
            end
          end

          jobs.each do |job|
            d_method = fetch_option(job, :dispatch_many_method, DEFAULTS)
            producer = producer(job)

            dispatches[d_method][producer] << dispatch_details(job).merge!(
              topic: job.queue_name,
              payload: ::ActiveSupport::JSON.encode(serialize_job(job))
            )
          end

          dispatches.each do |d_method, producers|
            producers.each do |producer, messages|
              producer.public_send(
                d_method,
                messages
              )
            end
          end
        end

        # Will enqueue a job to run in the future
        #
        # @param job [Object] job we want to enqueue
        # @param timestamp [Time] time when job should run
        def dispatch_at(job, timestamp)
          target_message = dispatch_details(job).merge!(
            topic: job.queue_name,
            payload: ::ActiveSupport::JSON.encode(serialize_job(job))
          )

          proxy_message = Pro::ScheduledMessages.schedule(
            message: target_message,
            epoch: timestamp.to_i,
            envelope: {
              # Select the scheduled messages proxy topic
              topic: fetch_option(job, :scheduled_messages_topic, DEFAULTS)
            }
          )

          producer(job).public_send(
            fetch_option(job, :dispatch_method, DEFAULTS),
            proxy_message
          )
        end

        private

        # Selects the producer based on options. If callable `:producer` is defined, it will use
        # it. If not, will just use the `Karafka.producer`.
        #
        # @param job [ActiveJob::Base] job instance
        # @return [WaterDrop::Producer, WaterDrop::Producer::Variant] producer or a variant
        def producer(job)
          dynamic_producer = fetch_option(job, :producer, DEFAULTS)

          dynamic_producer ? dynamic_producer.call(job) : ::Karafka.producer
        end

        # @param job [ActiveJob::Base] job instance
        # @return [Hash] hash with dispatch details to which we merge topic and payload
        def dispatch_details(job)
          partitioner = fetch_option(job, :partitioner, DEFAULTS)
          key_type = fetch_option(job, :partition_key_type, DEFAULTS)

          return {} unless partitioner

          {
            key_type => partitioner.call(job)
          }
        end
      end
    end
  end
end
