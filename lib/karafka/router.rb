require 'karafka/base_controller'
# main module namespace
module Karafka
  # Karafka framework Router for routing incoming events to proper controllers
  class Router
    attr_reader :topic, :message

    def initialize(topic, message)
      controller = Karafka::BaseController
        .descendants
        .detect { |klass| klass.topic == topic }

      fail 'Topic is undefined' unless controller
      puts '[][][][][[][][][]['
      puts controller.inspect
      controller
        .new(message)
        .process
    end
  end
end
