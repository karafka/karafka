module Karafka
  # Worker wrapper for Sidekiq workers
  class BaseWorker
    # include Sidekiq::Worker
    # sidekiq_options queue: 'highest'
    # sidekiq_options retry: false

    def self.perform(&_block)
      yield if block_given?
    end
  end
end
