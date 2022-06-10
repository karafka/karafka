# frozen_string_literal: true

module Karafka
  module Pro
    module Processing
      # Pro jobs builder that supports lrj
      class JobsBuilder < ::Karafka::Processing::JobsBuilder
        # @param executor [Karafka::Processing::Executor]
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
      end
    end
  end
end
