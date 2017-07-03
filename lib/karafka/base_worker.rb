# frozen_string_literal: true

module Karafka
  # Worker wrapper for Sidekiq workers
  class BaseWorker
    include Sidekiq::Worker

    # Executes the logic that lies in #perform Karafka controller method
    # @param topic [String] Topic that we will use to route to a proper controller
    # @param params [Hash] params hash that we use to build Karafka params object
    def perform(topic, params)
      Karafka.monitor.notice(self.class, params)
      controller(topic, params).perform
    end

    private

    # @return [Karafka::Controller] descendant of Karafka::BaseController that matches the topic
    #   with params assigned already (controller is ready to use)
    def controller(topic, params)
      @controller ||= Karafka::Routing::Router.new(topic).build.tap do |ctrl|
        ctrl.params = ctrl.interchanger.parse(params)
      end
    end
  end
end
