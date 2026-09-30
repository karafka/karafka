# frozen_string_literal: true

module Karafka
  module Processing
    module ShareGroups
      # Decides what type of job should be built to run a given share-group command and builds it.
      # Parallel to {Processing::ConsumerGroups::JobsBuilder}, but with only the job types the
      # share flow needs (consume + shutdown - there is no eof, revocation or idle handling).
      class JobsBuilder
        # @param executor [Karafka::Processing::ShareGroups::Executor]
        # @param messages [Array<Karafka::Messages::Message>] messages batch to be consumed
        # @return [Karafka::Processing::ShareGroups::Jobs::Consume] consumption job
        def consume(executor, messages)
          Jobs::Consume.new(executor, messages)
        end

        # @param executor [Karafka::Processing::ShareGroups::Executor]
        # @return [Karafka::Processing::ShareGroups::Jobs::Shutdown] shutdown job
        def shutdown(executor)
          Jobs::Shutdown.new(executor)
        end
      end
    end
  end
end
