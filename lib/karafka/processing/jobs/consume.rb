# frozen_string_literal: true

module Karafka
  module Processing
    module Jobs
      # The main job type. It runs the executor that triggers given topic partition messages
      # processing in an underlying consumer instance.
      class Consume < Base
        # @return [Array<Rdkafka::Consumer::Message>] array with messages
        attr_reader :messages

        self.action = :consume

        # @param executor [Karafka::Processing::Executor] executor that is suppose to run a given
        #   job
        # @param messages [Karafka::Messages::Messages] karafka messages batch
        # @return [Consume]
        def initialize(executor, messages)
          @executor = executor
          @messages = messages
          super()
        end

        # Runs all the preparation code on the executor that needs to happen before the job is
        # scheduled.
        def before_schedule
          executor.before_schedule_consume(@messages)
        end

        # Runs the before consumption preparations on the executor
        def before_call
          executor.before_consume
        end

        # Runs the given executor
        def call
          executor.consume
        end

        # Runs any error handling and other post-consumption stuff on the executor
        def after_call
          executor.after_consume
        end
      end
    end
  end
end
