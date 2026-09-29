# frozen_string_literal: true

module Karafka
  module Processing
    # Share-group (KIP-932) processing components. Parallel to {Processing::ConsumerGroups}, but
    # driven by per-record acknowledgements instead of partition offsets - there is no pausing,
    # seeking, eof or revocation coordination here.
    module ShareGroups
      # Minimal coordinator for share-group consumption. It tracks the running job count and the
      # success/failure state of a single poll batch, and carries the topic reference the consumer
      # needs. Unlike the consumer-group coordinator it has no pause tracker, seek offset, eof or
      # revocation state.
      #
      # @note A share poll batch may span multiple partitions. `#partition` is therefore reported
      #   as `-1` (not meaningful at the batch level); per-message partition is always available on
      #   each message.
      class Coordinator
        include Core::Helpers::Time

        # @return [Karafka::Routing::Topic] topic of the batch being coordinated
        attr_reader :topic

        # @return [Integer] always `-1` for share groups (batches are not partition-scoped)
        attr_reader :partition

        # @param topic [Karafka::Routing::Topic]
        def initialize(topic)
          @topic = topic
          @partition = -1
          @consumptions = {}
          @running_jobs = Hash.new { |h, k| h[k] = 0 }
          @mutex = Mutex.new
          @failure = false
        end

        # Resets the coordinator for a new batch of messages.
        #
        # @param _messages [Array<Karafka::Messages::Message>] batch we are about to coordinate
        def start(_messages)
          @mutex.synchronize do
            @failure = false
            @running_jobs[:consume] = 0
            @consumptions.clear
          end
        end

        # @param job_type [Symbol] type of job we want to increment
        def increment(job_type)
          @mutex.synchronize { @running_jobs[job_type] += 1 }
        end

        # @param job_type [Symbol] type of job we want to decrement
        def decrement(job_type)
          @mutex.synchronize do
            @running_jobs[job_type] -= 1

            return @running_jobs[job_type] unless @running_jobs[job_type].negative?

            raise Karafka::Errors::InvalidCoordinatorStateError, "Was zero before decrementation"
          end
        end

        # @return [Boolean] is all the consumption done and finished successfully
        def success?
          @mutex.synchronize do
            @running_jobs[:consume].zero? && @consumptions.values.all?(&:success?)
          end
        end

        # @param consumer [Karafka::Consumers::ShareGroup] consumer that finished successfully
        def success!(consumer)
          @mutex.synchronize { consumption(consumer).success! }
        end

        # @param consumer [Karafka::Consumers::ShareGroup] consumer that failed
        # @param error [StandardError] error that occurred
        def failure!(consumer, error)
          @mutex.synchronize do
            @failure = true
            consumption(consumer).failure!(error)
          end
        end

        # @return [Boolean] did any of the work we were running fail
        def failure?
          @failure
        end

        # Share groups have no partition revocation; always false. Present for API parity with the
        # consumer-group coordinator (used by e.g. `Consumers::Base#inspect`).
        #
        # @return [Boolean]
        def revoked?
          false
        end

        # @param consumer [Object] karafka consumer
        # @return [Karafka::Processing::Result] result object tracking consumption state
        def consumption(consumer)
          @consumptions[consumer] ||= Processing::Result.new
        end
      end
    end
  end
end
