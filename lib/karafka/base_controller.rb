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
    define_callbacks :schedule,
      terminator: ->(_target, result) { result == false }

    # This will be set based on routing settings
    # From 0.4 a single controller can handle multiple topics jobs
    attr_accessor :group, :topic, :worker, :parser, :interchanger

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

    # Creates lazy loaded params object
    # @note Until first params usage, it won't parse data at all
    # @param message [Karafka::Connection::Message, Hash] message with raw content or a hash
    #   from Sidekiq that allows us to build params.
    def params=(message)
      @params = Karafka::Params::Params.build(message, self)
    end

    # Executes the default controller flow, runs callbacks and if not halted
    # will schedule a perform task in sidekiq
    def schedule
      run_callbacks :schedule do
        perform_async
      end
    end

    # @return [Hash] hash with all controller details - it works similar to #params method however
    #   it won't parse data so it will return unparsed details about controller and its parameters
    # @example Get data about ctrl
    #   ctrl.to_h #=> { "worker"=>WorkerClass, "parsed"=>false, "content"=>"{}" }
    def to_h
      @params
    end

    private

    # @return [Karafka::Params::Params] Karafka params that is a hash with indifferent access
    # @note Params internally are lazy loaded before first use. That way we can skip parsing
    #   process if we have before_enqueue that rejects some incoming messages without using params
    #   It can be also used when handling really heavy data (in terms of parsing). Without direct
    #   usage outside of worker scope, it will pass raw data into sidekiq, so we won't use Karafka
    #   working time to parse this data. It will happen only in the worker (where it can take time)
    #   that way Karafka will be able to process data really quickly. On the other hand, if we
    #   decide to use params somewhere before it hits worker logic, it won't parse it again in
    #   the worker - it will use already loaded data and pass it to Redis
    # @note Invokation of this method will cause load all the data into params object. If you want
    #   to get access without parsing, please access @params directly
    def params
      @params.retrieve
    end

    # Enqueues the execution of perform method into a worker.
    # @note Each worker needs to have a class #perform_async method that will allow us to pass
    #   parameters into it. We always pass topic as a first argument and this request params
    #   as a second one (we pass topic to be able to build back the controller in the worker)
    def perform_async
      Karafka.monitor.notice(self.class, to_h)

      # We use @params directly (instead of #params) because of lazy loading logic that is behind
      # it. See Karafka::Params::Params class for more details about that
      worker.perform_async(
        topic,
        interchanger.load(@params)
      )
    end
  end
end
