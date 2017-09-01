# frozen_string_literal: true

# Karafka module namespace
module Karafka
  # Base controller from which all Karafka controllers should inherit
  # Similar to Rails controllers we can define after_received callbacks
  # that will be executed
  #
  # Note that if after_received return false, the chain will be stopped and
  #   the perform method won't be executed
  #
  # @example Create simple controller
  #   class ExamplesController < Karafka::BaseController
  #     def perform
  #       # some logic here
  #     end
  #   end
  #
  # @example Create a controller with a block after_received
  #   class ExampleController < Karafka::BaseController
  #     after_received do
  #       # Here we should have some checking logic
  #       # If false is returned, won't schedule a perform action
  #     end
  #
  #     def perform
  #       # some logic here
  #     end
  #   end
  #
  # @example Create a controller with a method after_received
  #   class ExampleController < Karafka::BaseController
  #     after_received :after_received_method
  #
  #     def perform
  #       # some logic here
  #     end
  #
  #     private
  #
  #     def after_received_method
  #       # Here we should have some checking logic
  #       # If false is returned, won't schedule a perform action
  #     end
  #   end
  class BaseController
    extend ActiveSupport::DescendantsTracker
    include ActiveSupport::Callbacks

    # The call method is wrapped with a set of callbacks
    # We won't run perform at the backend if any of the callbacks
    # returns false
    # @see http://api.rubyonrails.org/classes/ActiveSupport/Callbacks/ClassMethods.html#method-i-get_callbacks
    define_callbacks :after_received

    attr_accessor :params_batch

    class << self
      attr_reader :topic

      # Assigns a topic to a controller and build up proper controller functionalities, so it can
      #   cooperate with the topic settings
      # @param topic [Karafka::Routing::Topic]
      # @return [Karafka::Routing::Topic] assigned topic
      def topic=(topic)
        @topic = topic
        Controllers::Includer.call(self)
        @topic
      end

      # Creates a callback that will be executed after receiving message but before executing the
      #   backend for processing
      # @param method_name [Symbol, String] method name or nil if we plan to provide a block
      # @yield A block with a code that should be executed before scheduling
      # @example Define a block after_received callback
      #   after_received do
      #     # logic here
      #   end
      #
      # @example Define a class name after_received callback
      #   after_received :method_name
      def after_received(method_name = nil, &block)
        set_callback :after_received, :before, method_name ? method_name : block
      end
    end

    # @return [Karafka::Routing::Topic] topic to which a given controller is subscribed
    def topic
      self.class.topic
    end

    # Creates lazy loaded params batch object
    # @note Until first params usage, it won't parse data at all
    # @param messages [Array<Kafka::FetchedMessage>, Array<Hash>] messages with raw
    #   content (from Kafka) or messages inside a hash (from backend, etc)
    # @return [Karafka::Params::ParamsBatch] lazy loaded params batch
    def params_batch=(messages)
      @params_batch = Karafka::Params::ParamsBatch.new(messages, topic.parser)
    end

    # Executes the default controller flow, runs callbacks and if not halted
    # will call process method of a proper backend
    def call
      run_callbacks :after_received do
        process
      end
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
