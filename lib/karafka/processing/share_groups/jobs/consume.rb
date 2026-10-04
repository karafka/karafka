# frozen_string_literal: true

module Karafka
  module Processing
    module ShareGroups
      # Namespace for all the share-group jobs that are supposed to run in workers.
      module Jobs
        # The main share-group job type. It runs the executor that drives a share consumer over a
        # poll batch, acknowledging records per message.
        class Consume < ::Karafka::Processing::Jobs::Base
          # @return [Array<Karafka::Messages::Message>] messages to consume
          attr_reader :messages

          self.action = :consume

          # @param executor [Karafka::Processing::ShareGroups::Executor] executor that is supposed
          #   to run a given job
          # @param messages [Array<Karafka::Messages::Message>] karafka messages batch
          # @return [Consume]
          def initialize(executor, messages)
            @executor = executor
            @messages = messages
            super()
          end

          # Runs all the preparation code on the executor that needs to happen before the job is
          # scheduled (in the listener thread).
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
