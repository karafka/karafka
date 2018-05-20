# frozen_string_literal: true

module Karafka
  module Consumers
    # Additional callbacks that can be used to trigger some actions on certain moments like
    # manual offset management, committing or anything else outside of a standard messages flow
    # They are not included by default, as we don't want to provide functionalities that are
    # not required by users by default
    # Please refer to the wiki callbacks page for more details on how to use them
    module Callbacks
      # Types of events on which we run callbacks
      TYPES = %i[
        after_fetch
        after_poll
        before_poll
        before_stop
      ].freeze

      # Class methods needed to make callbacks run
      module ClassMethods
        TYPES.each do |type|
          # Creates a callback wrapper
          #
          # @param method_name [Symbol, String] method name or nil if we plan to provide a block
          # @yield A block with a code that should be executed before scheduling
          define_method(type) do |method_name = nil, &block|
            key = "consumers.#{Helpers::Inflector.map(self)}.#{type}"
            Karafka::App.events.register_event(key)

            Karafka::App.events.subscribe(key) do |event|
              context = event[:context]

              if method_name
                context.instance_exec(method_name) { |meth| method(meth).call }
              else
                context.instance_eval(&block)
              end
            end
          end
        end
      end

      # @param consumer_class [Class] consumer class that we extend with callbacks
      def self.included(consumer_class)
        consumer_class.class_eval do
          extend ClassMethods
        end
      end

      # Executes the default consumer flow, runs callbacks and if not halted will call process
      # method of a proper backend. It is here because it interacts with the default Karafka
      # call flow and needs to be overwritten to support callbacks
      def call
        if self.class.respond_to?(:after_fetch)
          Karafka::App.events.publish(
            "consumers.#{Helpers::Inflector.map!(self.class)}.after_fetch",
            context: self
          )
        end

        process
      end
    end
  end
end
