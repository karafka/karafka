# frozen_string_literal: true

module Karafka
  module Pro
    # Karafka Pro ActiveJob components
    module ActiveJob
      # This Karafka component is a Pro component.
      # All of the commercial components are present in the lib/karafka/pro directory of this
      # repository and their usage requires commercial license agreement.
      #
      # Karafka has also commercial-friendly license, commercial support and commercial components.
      #
      # By sending a pull request to the pro components, you are agreeing to transfer the copyright
      # of your code to Maciej Mensfeld.

      # Pro dispatcher that sends the ActiveJob job to a proper topic based on the queue name
      # and that allows to inject additional options into the producer, effectively allowing for a
      # much better and more granular control over the dispatch and consumption process.
      class Dispatcher < ::Karafka::ActiveJob::Dispatcher
        # Defaults for dispatching
        # They can be updated by using `#karafka_options` on the job
        DEFAULTS = {
          dispatch_method: :produce_async,
          # We don't create a dummy proc based partitioner as we would have to evaluate it with
          # each job.
          partitioner: nil
        }.freeze

        private_constant :DEFAULTS

        # @param job [ActiveJob::Base] job
        def call(job)
          ::Karafka.producer.public_send(
            fetch_option(job, :dispatch_method, DEFAULTS),
            dispatch_details(job).merge!(
              topic: job.queue_name,
              payload: ::ActiveSupport::JSON.encode(job.serialize)
            )
          )
        end

        private

        # @param job [ActiveJob::Base] job instance
        # @return [Hash] hash with dispatch details to which we merge topic and payload
        def dispatch_details(job)
          partitioner = fetch_option(job, :partitioner, DEFAULTS)

          return {} unless partitioner

          {
            partition_key: partitioner.call(job)
          }
        end
      end
    end
  end
end
