require 'karafka/base_controller'
# main module namespace
module Karafka
  # Karafka framework Router for routing incoming events to proper controllers
  class Router
    attr_reader :topic, :message
    # Raised when router receives topic name which is not provided for any of
    #  controllers(inherited from Karafka::BaseController)
    class UndefinedTopicError < StandardError; end

    # @param topic [String] topic name where we send message
    # @param message [JSON, String] message that we send
    # @return [Karafka::Router] router instance
    def initialize(topic, message)
      @topic = topic
      @message = message
    end

    # @raise [Karafka::Topic::UndefinedTopicError] raised if topic name is not match any
    # topic of descendants of Karafka::BaseController
    # Forwards message to controller inherited from Karafka::BaseController based on it's topic
    def forward
      descendant = Karafka::BaseController
        .descendants
        .detect { |klass| klass.topic.to_s == topic }

      fail UndefinedTopicError unless descendant

      controller = descendant.new
      controller.params = JSON.parse(message)
      controller.call
    end
  end
end
