module Karafka
  # Worker wrapper for Sidekiq workers
  class BaseWorker
    include Sidekiq::Worker

    attr_accessor :params, :topic

    # Executes the logic that lies in #perform Karafka controller method
    # @param topic [String] Topic that we will use to route to a proper controller
    # @param params [Hash] params hash that we use to build Karafka params object
    def perform(topic, params)
      self.topic = topic
      self.params = params
      Karafka.monitor.notice(self.class, controller.to_h)
      controller.perform
    end

    # What action should be taken when perform method fails
    # @param topic [String] Topic bthat we will use to route to a proper controller
    # @param params [Hash] params hash that we use to build Karafka params object
    def after_failure(topic, params)
      self.topic = topic
      self.params = params

      return unless controller.respond_to?(:after_failure)

      Karafka.monitor.notice(self.class, controller.to_h)
      controller.after_failure
    end

    private

    # @return [Karafka::Controller] descendant of Karafka::BaseController that matches the topic
    #   with params assigned already (controller is ready to use)
    def controller
      @controller ||= Karafka::Routing::Router.new(topic).build.tap do |ctrl|
        ctrl.params = ctrl.interchanger.parse(params)
      end
    end
  end
end
