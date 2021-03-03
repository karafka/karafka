# frozen_string_literal: true

module Karafka
  module Processing
    class ExecutorsBuffer
      def initialize(client, subscription_group, jobs_queue)
        @subscription_group = subscription_group
        @jobs_queue = jobs_queue
        @buffer = Hash.new { |h, k| h[k] = Hash.new  }
        @client = client
      end

      def fetch(
        topic,
        partition,
        pause
      )
        @buffer[topic][partition] ||= Executor.new(
          @client,
          @subscription_group.topics.find { |ktopic| ktopic.name == topic },
          pause
        )
      end

      def shutdown
        @buffer.values.map(&:values).flatten.each(&:shutdown)
      end

      def clear
        @buffer.values { |runner| @jobs_queue.clear(runner) }
        @buffer.clear
      end
    end
  end
end
