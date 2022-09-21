# frozen_string_literal: true

module Karafka
  module Processing
    # Basic coordinator that allows us to provide coordination objects into consumers.
    #
    # This is a wrapping layer to simplify management of work to be handled around consumption.
    #
    # @note This coordinator needs to be thread safe. Some operations are performed only in the
    #   listener thread, but we go with thread-safe by default for all not to worry about potential
    #   future mistakes.
    class Coordinator
      # @return [Karafka::TimeTrackers::Pause]
      attr_reader :pause_tracker

      attr_reader :seek_offset

      # @param pause_tracker [Karafka::TimeTrackers::Pause] pause tracker for given topic partition
      def initialize(pause_tracker)
        @pause_tracker = pause_tracker
        @revoked = false
        @consumptions = {}
        @running_jobs = 0
        @mutex = Mutex.new
      end

      # Starts the coordinator for given consumption jobs
      # @param messages [Array<Karafka::Messages::Message>] batch of message for which we are
      #   going to coordinate work. Not used with regular coordinator.
      def start(messages)
        @mutex.synchronize do
          @running_jobs = 0
          # We need to clear the consumption results hash here, otherwise we could end up storing
          # consumption results of consumer instances we no longer control
          @consumptions.clear

          # We set it on the first encounter and never again, because then the offset setting
          # should be up to the consumers logic (our or the end user)
          # Seek offset needs to be always initialized as for case where manual offset management
          # is turned on, we need to have reference to the first offset even in case of running
          # multiple batches without marking any messages as consumed. Rollback needs to happen to
          # the last place we know of or the last message + 1 that was marked
          @seek_offset ||= messages.first.offset
        end
      end

      # @param offset [Integer] message offset
      def seek_offset=(offset)
        @mutex.synchronize { @seek_offset = offset }
      end

      # Increases number of jobs that we handle with this coordinator
      def increment
        @mutex.synchronize { @running_jobs += 1 }
      end

      # Decrements number of jobs we handle at the moment
      def decrement
        @mutex.synchronize do
          @running_jobs -= 1

          return @running_jobs unless @running_jobs.negative?

          # This should never happen. If it does, something is heavily out of sync. Please reach
          # out to us if you encounter this
          raise Karafka::Errors::InvalidCoordinatorState, 'Was zero before decrementation'
        end
      end

      # @param consumer [Object] karafka consumer (normal or pro)
      # @return [Karafka::Processing::Result] result object which we can use to indicate
      #   consumption processing state.
      def consumption(consumer)
        @mutex.synchronize do
          @consumptions[consumer] ||= Processing::Result.new
        end
      end

      # Is all the consumption done and finished successfully for this coordinator
      def success?
        @mutex.synchronize { @running_jobs.zero? && @consumptions.values.all?(&:success?) }
      end

      # Marks given coordinator for processing group as revoked
      #
      # This is invoked in two places:
      #   - from the main listener loop when we detect revoked partitions
      #   - from the consumer in case checkpointing fails
      #
      # This means, we can end up having consumer being aware that it was revoked prior to the
      # listener loop dispatching the revocation job. It is ok, as effectively nothing will be
      # processed until revocation jobs are done.
      def revoke
        @mutex.synchronize { @revoked = true }
      end

      # @return [Boolean] is the partition we are processing revoked or not
      def revoked?
        @revoked
      end
    end
  end
end
