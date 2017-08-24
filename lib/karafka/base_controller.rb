# frozen_string_literal: true

# Karafka module namespace
module Karafka
  # Base controller from which all Karafka controllers should inherit
  # Similar to Rails controllers we can define before_enqueue callbacks
  # that will be executed
  #
  # Note that if before_enqueue return false, the chain will be stopped and
  #   the perform method won't be executed in sidekiq (won't peform_async it)
  #
  # @example Create simple controller
  #   class ExamplesController < Karafka::BaseController
  #     def perform
  #       # some logic here
  #     end
  #   end
  #
  # @example Create a controller with a block before_enqueue
  #   class ExampleController < Karafka::BaseController
  #     before_enqueue do
  #       # Here we should have some checking logic
  #       # If false is returned, won't schedule a perform action
  #     end
  #
  #     def perform
  #       # some logic here
  #     end
  #   end
  #
  # @example Create a controller with a method before_enqueue
  #   class ExampleController < Karafka::BaseController
  #     before_enqueue :before_method
  #
  #     def perform
  #       # some logic here
  #     end
  #
  #     private
  #
  #     def before_method
  #       # Here we should have some checking logic
  #       # If false is returned, won't schedule a perform action
  #     end
  #   end
  class BaseController
    extend ActiveSupport::DescendantsTracker
    include ActiveSupport::Callbacks

    # The schedule method is wrapped with a set of callbacks
    # We won't run perform at the backend if any of the callbacks
    # returns false
    # @see http://api.rubyonrails.org/classes/ActiveSupport/Callbacks/ClassMethods.html#method-i-get_callbacks
    define_callbacks :schedule

    attr_accessor :params_batch

    class << self
      attr_reader :topic

      # @param topic [Karafka::Routing::Topic]
      def topic=(topic)
        @topic = topic
        Controllers::Includer.call(self)
        @topic
      end

      # Creates a callback that will be executed before scheduling to Sidekiq
      # @param method_name [Symbol, String] method name or nil if we plan to provide a block
      # @yield A block with a code that should be executed before scheduling
      # @note If value returned is false, will chalt the chain and not schedlue to Sidekiq
      # @example Define a block before_enqueue callback
      #   before_enqueue do
      #     # logic here
      #   end
      #
      # @example Define a class name before_enqueue callback
      #   before_enqueue :method_name
      def before_enqueue(method_name = nil, &block)
        set_callback :schedule, :before, method_name ? method_name : block
      end
    end

    def topic
      self.class.topic
    end

    # Creates lazy loaded params batch object
    # @note Until first params usage, it won't parse data at all
    # @param messages [Array<Kafka::FetchedMessage>, Array<Hash>] messages with raw
    #   content (from Kafka) or messages inside a hash (from Sidekiq, etc)
    # @return [Karafka::Params::ParamsBatch] lazy loaded params batch
    def params_batch=(messages)
      @params_batch = Karafka::Params::ParamsBatch.new(messages, topic.parser)
    end

    # Executes the default controller flow, runs callbacks and if not halted
    # will schedule a call task in sidekiq
    def schedule
      run_callbacks :schedule do
        process
      end
    end

    # @note We want to leave the #perform method as a public API, but just in case we will do some
    #   pre or post processing we use call method instead of directly executing #perform
    def call
      perform
    end

    private

    # Method that will perform business logic on data received from Kafka
    # @note This method needs bo be implemented in a subclass. We stub it here as a failover if
    #   someone forgets about it or makes on with typo
    def perform
      raise NotImplementedError, 'Implement this in a subclass'
    end
  end
end
