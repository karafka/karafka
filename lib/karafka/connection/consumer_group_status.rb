# frozen_string_literal: true

module Karafka
  module Connection
    # This object represents a collective status of execution of group of listeners running inside
    # of one consumer group but potentially in separate subscription groups.
    #
    # There are cases when we do not want to close a given client when others from the same
    # consumer group are running because it can cause instabilities due to early shutdown of some
    # of the clients out of same consumer group.
    #
    # Here we can track it and only shutdown listeners when all work in a group is done.
    class ConsumerGroupStatus
      # @param group_size [Integer] number of separate subscription groups in a consumer group
      def initialize(group_size)
        @mutex = Mutex.new
        @active_size = group_size
      end

      # @return [Boolean] Are there any listeners that are still doing any type of work. If not,
      #   it means a consumer group is safe to be shutdown fully.
      def working?
        @active_size.positive?
      end

      # Decrements number of working listeners in the group by one until there's none
      def finish
        @mutex.synchronize do
          @active_size -= 1

          return if @active_size >= 0

          raise Errors::InvalidConsumerGroupStatusError, @active_size
        end
      end
    end
  end
end
