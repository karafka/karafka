# frozen_string_literal: true

module Karafka
  # Worker wrapper for Sidekiq workers
  class BaseWorker
    include Sidekiq::Worker

    # Executes the logic that lies in #perform Karafka controller method
    # @param topic_id [String] Unique topic id that we will use to find a proper topic
    # @param params [Hash] params hash that we use to build Karafka params object
    def perform(topic_id, params)
      Karafka.monitor.notice(self.class, params)
      controller(topic_id, params).perform
    end

    private

    # @return [Karafka::Controller] descendant of Karafka::BaseController that matches the topic
    #   with params assigned already (controller is ready to use)
    def controller(topic_id, params)
      @controller ||= Karafka::Routing::Router.build(topic_id).tap do |ctrl|
        ctrl.params = ctrl.topic.interchanger.parse(params)
      end
    end
  end
end
