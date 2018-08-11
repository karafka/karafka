# frozen_string_literal: true

module Karafka
  module Params
    # Simple metadata object that stores all non-message information received from Kafka cluster
    # while fetching the data
    class Metadata
          batch_size: batch.messages.count,
          partition: batch.partition,
offset_lag: batch.offset_lag,
{ listener_id: id, group_id: group_id, topic: topic, handler: handler_class.to_s }
    end
  end
end
