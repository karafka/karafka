# frozen_string_literal: true

module Karafka
  module Processing
    # Consumer-group-specific processing components (driven by rebalance callbacks and partition
    # ticks). Parallel `ShareGroups` will live next to this namespace once KIP-932 lands.
    module ConsumerGroups
      # Consumer-group-specific job types
      module Jobs
        # The main job type. It runs the executor that triggers given topic partition messages
        # processing in an underlying consumer instance.
        class Consume < Processing::Jobs::Base
          # @return [Array<Rdkafka::Consumer::Message>] array with messages
          attr_reader :messages

          self.action = :consume

          # @param executor [Karafka::Processing::ConsumerGroups::Executor] executor that is suppose to run a given
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
end
