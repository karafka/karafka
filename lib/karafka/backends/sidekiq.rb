# frozen_string_literal: true

module Karafka
  module Backends
    # Sidekiq backend that schedules stuff to Sidekiq worker for delayed execution
    module Sidekiq
      private

      # Enqueues the execution of perform method into a worker.
      # @note Each worker needs to have a class #perform_async method that will allow us to pass
      #   parameters into it. We always pass topic as a first argument and this request
      #   params_batch as a second one (we pass topic to be able to build back the controller
      #   in the worker)
      def process
        Karafka.monitor.notice(self.class, params_batch)
        topic.worker.perform_async(
          topic.id,
          topic.interchanger.load(params_batch.to_a)
        )
      end
    end
  end
end
