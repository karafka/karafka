module Karafka
  # Worker wrapper for Sidekiq workers
  class Worker < ::SidekiqGlass::Worker
    attr_accessor :args

    # @param args [Array] controller params and controller topic
    # @note Arguments are provided in Karafka::BaseController enqueue
    def execute(*args)
      self.args = args
      controller.perform
    end

    # What action should be taken when execute method fails
    # With after_failure we can provide reentrancy to this worker
    # @param args [Array] controller params and controller topic
    def after_failure(*args)
      self.args = args
      return unless controller.respond_to?(:after_failure)

      controller.after_failure
    end

    private

    # @return [Karafka::Params] Karafka Params instance
    # @note It behaves similar to Rails params
    def params
      @params ||= Karafka::Params.new(args.first)
    end

    # @return [Karafka::Controller] descendant of Karafka::BaseController that matches the topic
    def controller
      @controller ||= Karafka::Routing::Router.new(
        Karafka::Connection::Event.new(params[:topic], params)
      ).build
    end
  end
end
