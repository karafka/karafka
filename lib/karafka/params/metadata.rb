# frozen_string_literal: true

module Karafka
  module Params
    # Simple metadata object that stores all non-message information received from Kafka cluster
    # while fetching the data
    class Metadata
      attr_reader :topic
      attr_reader :batch_size
      attr_reader :partition
      attr_reader :offset_lag
      attr_reader :group_id

      def initialize(batch)

      end
#           batch_size: batch.messages.count,
#           partition: batch.partition,
# offset_lag: batch.offset_lag,
# { listener_id: id, group_id: group_id, topic: topic, handler: handler_class.to_s }
    end
  end
end
