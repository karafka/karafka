require 'sidekiq_glass'
require 'karafka'
require 'karafka/base_controller'
require './../../examples/run_test'

module Karafka
  # Worker wrapper for Sidekiq workers
  class BaseWorker < SidekiqGlass::Worker
    self.timeout = 300
    sidekiq_options queue: 'highest5'
    # Perform method

    def execute(*params)
      logger = Sidekiq::Logging.logger
      logger.info params.first['topic'].inspect
      topic = params.first['topic']
      controller = Karafka::BaseController.descendants
        .detect { |klass| klass.topic.to_s == topic }
      return unless controller
      s = controller.new
      s.params = Karafka::Params.new(params).parse
    end
    #
    # def after_failure(*usernames)
    #   # AccountsService.new.reset(usernames)
    # end
  end
end
