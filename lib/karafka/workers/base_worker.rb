module Karafka
  # Module encapsulating code related to Sidekiq workers logic
  module Workers
    # Worker wrapper for Sidekiq workers
    class BaseWorker < ::SidekiqGlass::Worker
      attr_accessor :params

      # @param args [Array] controller params and controller topic
      # @note Arguments are provided in Karafka::BaseController enqueue
      def execute(*args)
        self.params = args.first
        Karafka.logger.info("#{self.class}#execute for #{params}")
        controller.perform
      end

      # What action should be taken when execute method fails
      # With after_failure we can provide reentrancy to this worker
      # @param args [Array] controller params and controller topic
      def after_failure(*args)
        self.params = args.first

        unless controller.respond_to?(:after_failure)
          Karafka.logger.warn("#{self.class}#after_failure controller missing for #{params}")
          return
        end

        Karafka.logger.warn("#{self.class}#after_failure for #{args}")
        controller.after_failure
      end

      private

      # @return [Karafka::Controller] descendant of Karafka::BaseController that matches the topic
      #   with params assigned already (controller is ready to use)
      # @note We don't use router here because in Sidekiq params (args) we alread know what
      #   controller it is going to be
      def controller
        @controller ||= Kernel.const_get(params['controller']).new.tap do |ctrl|
          ctrl.params = params
        end
      end
    end
  end
end
