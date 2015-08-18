require 'sidekiq_glass'
require 'karafka'
require 'karafka/base_controller'
require './../../examples/run_test'

Karafka::Loader.new.load!("#{Karafka.root}/app/controllers")
module Karafka
  # Worker wrapper for Sidekiq workers
  class BaseWorker < SidekiqGlass::Worker
    self.timeout = 300

    # Perform method
    def execute(*params)
      topic = params.last.to_sym

      event = Karafka::Connection::Event.new(topic, params.first)
      controller = Karafka::Routing::Router.new(event).descendant_controller

      controller.perform
    end
    #
    # def after_failure(*usernames)
    #   # AccountsService.new.reset(usernames)
    # end
  end
end
