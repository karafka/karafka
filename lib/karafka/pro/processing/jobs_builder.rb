# frozen_string_literal: true

# This Karafka component is a Pro component.
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
