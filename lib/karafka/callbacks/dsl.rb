# frozen_string_literal: true

module Karafka
  module Callbacks
    # App level dsl to define callbacks
    module Dsl
      # Allows us to define a block that will be executed after Karafka has been initialized
      # @param [Block] block that should be executed after the initialization process
      def after_init(&block)
        Karafka.event_publisher.subscribe('app.after_init') do |payload|
          # We have to unpack the payload to keep backward-compatibility
          block.call(payload[:config])
        end
      end

      # Allows us to define a block that will be executed before fetch_loop starts
      # @param [Block] block that should be executed after the initialization process
      def before_fetch_loop(&block)
        Karafka.event_publisher.subscribe('connection.listener.before_fetch_loop') do |payload|
          # We have to unpack the payload to keep backward-compatibility
          block.call(payload[:consumer_group], payload[:client])
        end
      end
    end
  end
end
