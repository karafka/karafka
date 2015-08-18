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
      event = Karafka::Connection::Event.new(params.last.to_sym, params.first)
      controller = Karafka::Routing::Router.new(event).descendant_controller

      controller.perform
    end

    def after_failure(*_params)
    end
  end
end
