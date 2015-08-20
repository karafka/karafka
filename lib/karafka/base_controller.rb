# Karafka module namespace
module Karafka
  # Base controller from which all Karafka controllers should inherit
  # Similar to Rails controllers we can define before_enqueue callbacks
  # that will be executed
  # Note that if before_enqueue return false, the chain will be stopped and
  # the perform method won't be executed in sidekiq (won't peform_async it)
  # @example Create simple controller
  #   class ExampleController < Karafka::BaseController
  #     self.group = :kafka_group_name
  #     self.topic = :kafka_topic
  #
  #     def perform
  #       # some logic here
  #     end
  #   end
  #
  # @example Create a controller with a block before_enqueue
  #   class ExampleController < Karafka::BaseController
  #     self.group = :kafka_group_name
  #     self.topic = :kafka_topic
  #
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
  #     self.group = :kafka_group_name
  #     self.topic = :kafka_topic
  #
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
  #     self.group = :kafka_group_name
  #     self.topic = :kafka_topic
  #
  #     def perform
  #       # some logic here
  #     end
  #
  #     def after_failure
  #       # action taken in case perform fails
  #     end
  #   end
  class BaseController
    include ActiveSupport::Callbacks

    attr_reader :params

    # Raised when we have a controller that does not have a group set
    class GroupNotDefined < StandardError; end
    # Raised when we have a controller that does not have a topic set
    class TopicNotDefined < StandardError; end
    # Raised when we have a controller that does not have a perform method that is required
    class PerformMethodNotDefined < StandardError; end

    # The call method is wrapped with a set of callbacks
    # We won't run perform at the backend if any of the callbacks
    # returns false
    # @see http://api.rubyonrails.org/classes/ActiveSupport/Callbacks/ClassMethods.html#method-i-get_callbacks
    define_callbacks :call,
      terminator: ->(_target, result) { result == false }

    class << self
      # Kafka group and topic must be defined
      attr_accessor :group, :topic

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
        Karafka.logger.debug("Defining before_enqueue filter with #{block}")
        set_callback :call, :before, method_name ? method_name : block
      end
    end

    # @raise [Karafka::BaseController::GroupNotDefined] raised if we didn't define kafka group
    # @raise [Karafka::BaseController::TopicNotDefined] raised if we didn't define kafka topic
    # @raise [Karafka::BaseController::PerformMethodNotDefined] raised if we
    #   didn't define the perform method
    def initialize
      fail GroupNotDefined unless self.class.group
      fail TopicNotDefined unless self.class.topic
      fail PerformMethodNotDefined unless self.respond_to?(:perform)
    end

    # Assigns parameters hash (Karafka::Params) internally. It also adds some extra
    #  flavour values to it
    # @param params [Karafka::Params] params instance
    def params=(params)
      @params = params.tap do |param|
        param.merge!(
          controller: self.class,
          topic: self.class.topic
        )
      end
    end

    # Executes the default controller flow, runs callbacks and if not halted
    # will schedule a perform task in sidekiq
    def call
      run_callbacks :call do
        enqueue
      end
    end

    private

    # Enqueues the execution of perform method into sidekiq worker
    def enqueue
      Karafka.logger.info("Enqueuing #{self.class} - #{params}")
      Karafka::Worker.perform_async(params)
    end
  end
end
