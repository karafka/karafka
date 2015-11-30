module Karafka
  # Module encapsulating code related to Sidekiq workers logic
  module Workers
    # Worker wrapper for Sidekiq workers
    class BaseWorker < ::SidekiqGlass::Worker
      attr_accessor :params, :controller_class_name

      # Executes the logic that lies in #perform Karafka controller method
      # @param controller_class_name [String] descendant of Karafka::BaseController
      # @param params [Hash] params hash that we use to build Karafka params object
      def execute(controller_class_name, params)
        self.controller_class_name = controller_class_name
        self.params = params
        Karafka.monitor.notice(self.class, params: params)
        controller.perform
      end

      # What action should be taken when execute method fails
      # @param controller_class_name [Class] descendant of Karafka::BaseController
      # @param params [Hash] params hash that we use to build Karafka params object
      def after_failure(controller_class_name, params)
        self.controller_class_name = controller_class_name
        self.params = params

        return unless controller.respond_to?(:after_failure)

        Karafka.monitor.notice(self.class, params: params)
        controller.after_failure
      end

      private

      # @return [Karafka::Controller] descendant of Karafka::BaseController that matches the topic
      #   with params assigned already (controller is ready to use)
      # @note We don't use router here because we get the controller class name from Sidekiq params
      #   The only thinng we need to do, is to get the appropriate class based on its name
      def controller
        @controller ||= Kernel.const_get(controller_class_name).new.tap do |ctrl|
          ctrl.params = ctrl.class.interchanger.parse(params)
        end
      end
    end
  end
end
