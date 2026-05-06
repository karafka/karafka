# frozen_string_literal: true

module Karafka
  module Processing
    module ConsumerGroups
      # Class responsible for deciding what type of job should we build to run a given command and
      # for building a proper job for it.
      class JobsBuilder
        # @param executor [Karafka::Processing::ConsumerGroups::Executor]
        # @param messages [Karafka::Messages::Messages] messages batch to be consumed
        # @return [Karafka::Processing::ConsumerGroups::Jobs::Consume] consumption job
        def consume(executor, messages)
          Jobs::Consume.new(executor, messages)
        end

        # @param executor [Karafka::Processing::ConsumerGroups::Executor]
        # @return [Karafka::Processing::ConsumerGroups::Jobs::Eofed] eofed job
        def eofed(executor)
          Jobs::Eofed.new(executor)
        end

        # @param executor [Karafka::Processing::ConsumerGroups::Executor]
        # @return [Karafka::Processing::ConsumerGroups::Jobs::Revoked] revocation job
        def revoked(executor)
          Jobs::Revoked.new(executor)
        end

        # @param executor [Karafka::Processing::ConsumerGroups::Executor]
        # @return [Karafka::Processing::ConsumerGroups::Jobs::Shutdown] shutdown job
        def shutdown(executor)
          Jobs::Shutdown.new(executor)
        end
      end
    end
  end
end
