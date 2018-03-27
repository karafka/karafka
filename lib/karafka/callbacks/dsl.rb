# frozen_string_literal: true

module Karafka
  # Callbacks. This module is deprecated.
  module Callbacks
    # App level dsl to define callbacks
    module Dsl
      # Allows us to define a block that will be executed after Karafka has been initialized
      # @yield [config] block that should be executed after the initialization process
      # @yieldparam [Hash] config Karafka config
      def after_init
        Karafka.event_publisher.subscribe('app.after_init') do |payload|
          # We have to unpack the payload to keep backward-compatibility
          yield payload[:config]
        end
      end

      # Allows us to define a block that will be executed before fetch_loop starts
      # @yield [consumer_group, client] # block that should be executed after
      # the initialization process
      # @yieldparam [Karafka::Routing::ConsumerGroup] consumer_group
      # @yieldparam [Karafka::Connection::Client] client
      def before_fetch_loop
        Karafka.event_publisher.subscribe('connection.listener.before_fetch_loop') do |payload|
          # We have to unpack the payload to keep backward-compatibility
          yield payload[:consumer_group], payload[:client]
        end
      end
    end
  end
end
