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
  #
  # @example Create a controller with an after_failure action
  #   class ExampleController < Karafka::BaseController
  #     def perform
  #       # some logic here
  #     end
  #
  #     def after_failure
  #       # action taken in case perform fails
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

    # Each controller instance is always bind to a single topic. We don't place it on a class
    # level because some programmers use same controller for multiple topics
    attr_accessor :topic
    attr_accessor :params_batch

    class << self
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

    # Creates lazy loaded params batch object
    # @note Until first params usage, it won't parse data at all
    # @param messages [Array<Kafka::FetchedMessage>, Array<Hash>] messages with raw
    #   content (from Kafka) or messages inside a hash (from Sidekiq, etc)
    # @return [Karafka::Params::ParamsBatch] lazy loaded params batch
    def params_batch=(messages)
      @params_batch = Karafka::Params::ParamsBatch.new(messages, topic.parser)
    end

    # @return [Karafka::Params::Params] params instance for non batch processed controllers
    # @raise [Karafka::Errors::ParamsMethodUnavailable] raised when we try to use params
    #   method in a batch_processed controller
    def params
      raise Karafka::Errors::ParamsMethodUnavailable if topic.batch_processing
      params_batch.first
    end

    # Executes the default controller flow, runs callbacks and if not halted
    # will schedule a call task in sidekiq
    def schedule
      run_callbacks :schedule do
        topic.inline_mode ? call_inline : call_async
      end
    end

    # @note We want to leave the #perform method as a public API, but we need to do some
    # postprocessing after the user code has been executed, so we expose internally a #call
    # for that
    def call
      perform
      # Since responder has an internal validation during the response process, it would be
      # useless to validate it twice (if used), but when responder is not being used in the
      # #respond_with, we need to validate that it definition does not require it to be used
      # @see https://github.com/karafka/karafka/issues/181
      responder&.send(:validate!) unless @responded_with_data
    end

    private

    # Method that will perform business logic on data received from Kafka
    # @note This method needs bo be implemented in a subclass. We stub it here as a failover if
    #   someone forgets about it or makes on with typo
    def perform
      raise NotImplementedError, 'Implement this in a subclass'
    end

    # @return [Karafka::BaseResponder] responder instance if defined
    # @return [nil] nil if no responder for this controller
    def responder
      @responder ||= topic.responder&.new(topic.parser)
    end

    # Responds with given data using given responder. This allows us to have a similar way of
    # defining flows like synchronous protocols
    # @param data Anything we want to pass to responder based on which we want to trigger further
    #   Kafka responding
    # @raise [Karafka::Errors::ResponderMissing] raised when we don't have a responder defined,
    #   but we still try to use this method
    def respond_with(*data)
      raise(Errors::ResponderMissing, self.class) unless responder
      @responded_with_data = true
      Karafka.monitor.notice(self.class, data: data)
      responder.call(*data)
    end

    # Executes perform code immediately (without enqueuing)
    # @note Despite the fact, that workers won't be used, we still initialize all the
    #   classes and other framework elements
    def call_inline
      Karafka.monitor.notice(self.class, params_batch)
      call
    end

    # Enqueues the execution of perform method into a worker.
    # @note Each worker needs to have a class #perform_async method that will allow us to pass
    #   parameters into it. We always pass topic as a first argument and this request params_batch
    #   as a second one (we pass topic to be able to build back the controller in the worker)
    def call_async
      Karafka.monitor.notice(self.class, params_batch)
      topic.worker.perform_async(
        topic.id,
        topic.interchanger.load(params_batch.to_a)
      )
    end
  end
end
