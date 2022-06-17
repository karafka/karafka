# frozen_string_literal: true

module Karafka
  module Processing
    module Jobs
      # The main job type. It runs the executor that triggers given topic partition messages
      # processing in an underlying consumer instance.
      class Consume < Base
        # @return [Array<Rdkafka::Consumer::Message>] array with messages
        attr_reader :messages

        # @param executor [Karafka::Processing::Executor] executor that is suppose to run a given
        #   job
        # @param messages [Karafka::Messages::Messages] karafka messages batch
        # @return [Consume]
        def initialize(executor, messages)
          @executor = executor
          @messages = messages
          @created_at = Time.now
          super()
        end

        # Runs the preparations on the executor
        def before_call
          executor.before_consume(@messages, @created_at)
        end

        # Runs the given executor
        def call
          executor.consume
        end
      end
    end
  end
end
