# frozen_string_literal: true

module Karafka
  # Flat, user-facing base for share-group (KIP-932) consumers - the share-group counterpart of
  # {Karafka::BaseConsumer}. It is an alias of the canonical {Karafka::Consumers::ShareGroup}. The
  # name mirrors Kafka's `KafkaShareConsumer` and `Rdkafka::ShareConsumer`, so applications
  # subclass it the same way they subclass `BaseConsumer` for consumer groups:
  #
  #   class ApplicationShareConsumer < Karafka::ShareConsumer
  #   end
  ShareConsumer = Consumers::ShareGroup
end
