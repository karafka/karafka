# frozen_string_literal: true

module Karafka
  # Worker wrapper for Sidekiq workers
  class BaseWorker
    include Sidekiq::Worker

    # Executes the logic that lies in #perform Karafka controller method
    # @param topic_id [String] Unique topic id that we will use to find a proper topic
    # @param params_batch [Array] Array with messages batch
    def perform(topic_id, params_batch)
      Karafka.monitor.notice(self.class, params_batch)
      controller(topic_id, params_batch).perform
    end

    private

    # @return [Karafka::Controller] descendant of Karafka::BaseController that matches the topic
    #   with params_batch assigned already (controller is ready to use)
    def controller(topic_id, params_batch)
      topic = Karafka::Routing::Router.find(topic_id)
      controller = topic.controller.new
      controller.params_batch = topic.interchanger.parse(params_batch)
      controller
    end
  end
end
