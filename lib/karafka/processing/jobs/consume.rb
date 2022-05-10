# frozen_string_literal: true

module Karafka
  module Processing
    module Jobs
      # The main job type. It runs the executor that triggers given topic partition messages
      # processing in an underlying consumer instance.
      class Consume < Base
        # @param executor [Karafka::Processing::Executor] executor that is suppose to run a given
        #   job
        # @param messages [Array<dkafka::Consumer::Message>] array with raw rdkafka messages with
        #   which we are suppose to work
        # @return [Consume]
        def initialize(executor, messages)
          @executor = executor
          @messages = messages
          @created_at = Time.now
          super()
        end

        # Runs the preparations on the executor
        def prepare
          executor.prepare(@messages, @created_at)
        end

        # Runs the given executor
        def call
          executor.consume
        end
      end
    end
  end
end
