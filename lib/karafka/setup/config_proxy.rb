# frozen_string_literal: true

module Karafka
  module Setup
    # Configuration proxy that wraps the actual config object during the setup phase.
    #
    # ## Purpose
    #
    # This proxy exists to intercept specific configuration methods during the setup block
    # execution, allowing for deferred initialization and special handling of certain
    # configuration aspects without permanently modifying the config object's API.
    #
    # The key design principle is: **the proxy only exists during setup and doesn't pollute
    # the permanent config API**. Once setup is complete, all access goes directly to the
    # real config object.
    #
    # ## Why Use a Proxy?
    #
    # During Karafka setup, there's a specific order of operations:
    #
    # 1. User configures basic settings (kafka, client_id, etc.)
    # 2. Config validation runs
    # 3. Components are initialized based on finalized config
    # 4. Post-setup hooks execute
    #
    # Some configuration needs to happen **after** user settings but **during** component
    # initialization. The proxy intercepts these special cases during step 1, stores the
    # instructions, and applies them during step 3.
    #
    # ## Current Use Case: Producer Configuration
    #
    # The proxy currently intercepts `producer` calls with blocks:
    #
    # ```ruby
    # Karafka::App.setup do |config|
    #   config.kafka = { 'bootstrap.servers': 'localhost:9092' }
    #
    #   # This is intercepted by the proxy
    #   config.producer do |producer_config|
    #     producer_config.kafka['compression.type'] = 'snappy'
    #   end
    # end
    # ```
    #
    # Without the proxy, we'd have two problems:
    #
    # 1. **Permanent API pollution**: Adding a `producer` method to config that accepts blocks
    #    would change its permanent API, even though this functionality is only needed during
    #    setup.
    #
    # 2. **Timing issues**: The producer doesn't exist yet when the user's setup block runs.
    #    The producer is created in `configure_components` after all user configuration is
    #    complete. We need to store the user's producer configuration block and apply it
    #    later at the right time.
    #
    # The proxy solves both:
    # - It only exists during the setup call
    # - It stores the producer configuration block in an instance variable
    # - After setup, the block is passed to `configure_components` for execution
    # - The proxy is then discarded
    #
    # ## Future Use Cases
    #
    # This pattern can be extended for other deferred configuration needs:
    #
    # - **Monitor configuration**: Intercept monitor setup to configure it after all components
    #   are initialized
    # - **Custom component initialization**: Allow users to configure internal components that
    #   need access to the fully-configured environment
    # - **Feature toggles**: Enable/disable features based on the complete configuration state
    #
    # ## Implementation Details
    #
    # The proxy is a simple wrapper object that:
    # 1. Implements specific interceptor methods (currently just `producer`)
    # 2. Delegates everything else to the wrapped config via `method_missing`
    # 3. Stores deferred configuration in instance variables
    #
    # ## Lifecycle
    #
    # ```
    # Setup.setup(&block)
    #   ↓
    # proxy = ConfigProxy.new(config)  # Create proxy
    #   ↓
    # configure { yield(proxy) }       # User block receives proxy
    #   ↓
    # [User calls config methods]      # Most delegate to real config
    #   ↓
    # [User calls config.producer {}]  # Intercepted by proxy
    #   ↓
    # configure_components(proxy.producer_initialization_block)  # Block retrieved
    #   ↓
    # [Block executed with real producer config]
    #   ↓
    # proxy = nil                      # Proxy discarded
    # ```
    #
    # ## Thread Safety
    #
    # The proxy is created once per setup call and is not shared between threads. Each setup
    # invocation gets its own proxy instance.
    #
    # ## Example Usage
    #
    # ```ruby
    # class KarafkaApp < Karafka::App
    #   setup do |config|
    #     # Standard config access - delegated to real config
    #     config.kafka = { 'bootstrap.servers': 'localhost:9092' }
    #     config.client_id = 'my_app'
    #
    #     # Special intercepted method - handled by proxy
    #     config.producer do |producer_config|
    #       producer_config.kafka['compression.type'] = 'snappy'
    #       producer_config.kafka['linger.ms'] = 10
    #       producer_config.max_wait_timeout = 60_000
    #     end
    #   end
    # end
    # ```
    #
    # @see Karafka::Setup::Config.setup
    # @see Karafka::Setup::Config.configure_components
    class ConfigProxy
      # @return [Proc] the stored producer initialization block (defaults to empty proc)
      attr_reader :producer_initialization_block

      # Creates a new configuration proxy wrapping the actual config object.
      #
      # The producer initialization block defaults to an empty proc, eliminating the need for
      # nil checks when executing the block in {#configure_components}.
      #
      # @param config [Karafka::Setup::Config::Node] the actual config object to wrap
      #
      # @example
      #   proxy = ConfigProxy.new(Karafka::App.config)
      def initialize(config)
        @config = config
        @producer_initialization_block = ->(_) {}
      end

      # Captures a block for producer configuration or delegates producer assignment to config.
      #
      # This method has dual behavior:
      #
      # 1. **With a block**: Stores the block for later execution after the producer is created.
      #    This allows users to customize producer settings without manually creating a producer
      #    instance.
      #
      # 2. **With an instance**: Delegates to `config.producer=` for direct producer assignment.
      #    This preserves the existing API for users who want to provide their own producer.
      #
      # The block is stored in `@producer_initialization_block` and later passed to
      # `configure_components` where it's executed with the producer's config object.
      #
      # ## Why This Exists
      #
      # The producer is created in `configure_components` after all user configuration is
      # complete. This ensures the producer inherits the correct kafka settings. However,
      # users may want to customize the producer further (add middleware, change timeouts,
      # etc.) without creating their own producer instance.
      #
      # This method bridges the gap: it lets users configure the producer **as if it exists**
      # during setup, but actually defers the configuration until after it's created.
      #
      # ## Block Execution Timing
      #
      # ```
      # setup do |config|
      #   config.kafka = { ... }        # Runs immediately
      #
      #   config.producer do |pc|       # Block STORED (not executed yet)
      #     pc.kafka['...'] = '...'
      #   end
      # end
      # # User block complete
      # # Config validation runs
      # # configure_components creates producer
      # # NOW the stored block executes: block.call(producer.config)
      # ```
      #
      # @param instance [WaterDrop::Producer, nil] optional producer instance for direct
      #   assignment
      # @param block [Proc] optional block for producer configuration. Will be called with
      #   the producer's config object after the producer is created.
      # @return [void]
      #
      # @example Configuring producer with a block
      #   config.producer do |producer_config|
      #     producer_config.kafka['compression.type'] = 'snappy'
      #     producer_config.max_wait_timeout = 30_000
      #     producer_config.middleware.append(MyMiddleware.new)
      #   end
      #
      # @example Direct producer assignment
      #   custom_producer = WaterDrop::Producer.new { |c| c.kafka = { ... } }
      #   config.producer = custom_producer
      def producer(instance = nil, &block)
        if block
          # Store the configuration block for later execution
          @producer_initialization_block = block
        else
          # Direct assignment - delegate to real config
          @config.producer = instance
        end
      end

      # Delegates all other method calls to the wrapped config object.
      #
      # This is the core delegation mechanism. Any method not explicitly defined on the proxy
      # is forwarded to the real config object. This makes the proxy transparent for all
      # standard configuration access.
      #
      # ## Ruby 2.7+ Argument Forwarding
      #
      # Uses `...` syntax to forward all arguments, keyword arguments, and blocks efficiently
      # without explicitly naming them. This is more performant and maintainable than the
      # older `*args, **kwargs, &block` pattern.
      #
      # @param method [Symbol] the method name
      # @return [Object] whatever the delegated method returns
      #
      # @example
      #   proxy.kafka = { ... }           # Delegates to config.kafka=
      #   proxy.client_id = 'app'         # Delegates to config.client_id=
      #   value = proxy.max_wait_time     # Delegates to config.max_wait_time
      def method_missing(method, ...)
        @config.public_send(method, ...)
      end

      # Responds to methods that the wrapped config responds to.
      #
      # This makes the proxy appear to have all the same methods as the config object,
      # which is important for introspection and compatibility with code that checks
      # `respond_to?` before calling methods.
      #
      # @param method [Symbol] the method name
      # @param include_private [Boolean] whether to include private methods
      # @return [Boolean] true if the config responds to the method
      #
      # @example
      #   proxy.respond_to?(:kafka)          # => true
      #   proxy.respond_to?(:producer)       # => true (defined on proxy)
      #   proxy.respond_to?(:unknown)        # => false
      def respond_to_missing?(method, include_private = false)
        @config.respond_to?(method, include_private)
      end
    end
  end
end
