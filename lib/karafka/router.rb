require 'karafka/base_controller'
# main module namespace
module Karafka
  # Karafka framework Router for routing incoming events to proper controllers
  class Router
    attr_reader :topic, :message

    class UndefinedTopicError < StandardError; end

    def initialize(topic, message)
      controller = Karafka::BaseController
        .descendants
        .detect { |klass| klass.topic.to_s == topic }

      raise UndefinedTopicError unless controller
      controller
        .new(message)
        .call
    end
  end
end
