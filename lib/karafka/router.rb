require 'karafka/base_controller'
# main module namespace
module Karafka
  # Karafka framework Router for routing incoming events to proper controllers
  class Router
    attr_reader :topic, :message

    class UndefinedTopicError < StandardError; end

    def initialize(topic, message)
      @topic = topic
      @message = message
    end

    def forward
      controller = Karafka::BaseController
        .descendants
        .detect { |klass| klass.topic.to_s == topic }

      fail UndefinedTopicError unless controller
      controller
        .new(message)
        .call
    end
  end
end
