# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      # Pro jobs builder that supports lrj
      class JobsBuilder < ::Karafka::Processing::JobsBuilder
        # @param executor [Karafka::Pro::Processing::Executor]
        def idle(executor)
          Karafka::Processing::Jobs::Idle.new(executor)
        end

        # @param executor [Karafka::Pro::Processing::Executor]
        # @param messages [Karafka::Messages::Messages] messages batch to be consumed
        # @return [Karafka::Processing::Jobs::Consume] blocking job
        # @return [Karafka::Pro::Processing::Jobs::ConsumeNonBlocking] non blocking for lrj
        def consume(executor, messages)
          if executor.topic.long_running_job?
            Jobs::ConsumeNonBlocking.new(executor, messages)
          else
            super
          end
        end

        # @param executor [Karafka::Pro::Processing::Executor]
        # @return [Karafka::Processing::Jobs::Eofed] eofed job for non LRJ
        # @return [Karafka::Processing::Jobs::EofedBlocking] eofed job that is
        #   non-blocking, so when revocation job is scheduled for LRJ it also will not block
        def eofed(executor)
          if executor.topic.long_running_job?
            Jobs::EofedNonBlocking.new(executor)
          else
            super
          end
        end

        # @param executor [Karafka::Pro::Processing::Executor]
        # @return [Karafka::Processing::Jobs::Revoked] revocation job for non LRJ
        # @return [Karafka::Processing::Jobs::RevokedNonBlocking] revocation job that is
        #   non-blocking, so when revocation job is scheduled for LRJ it also will not block
        def revoked(executor)
          if executor.topic.long_running_job?
            Jobs::RevokedNonBlocking.new(executor)
          else
            super
          end
        end

        # @param executor [Karafka::Pro::Processing::Executor]
        # @return [Jobs::Periodic] Periodic job
        # @return [Jobs::PeriodicNonBlocking] Periodic non-blocking job
        def periodic(executor)
          if executor.topic.long_running_job?
            Jobs::PeriodicNonBlocking.new(executor)
          else
            Jobs::Periodic.new(executor)
          end
        end
      end
    end
  end
end
