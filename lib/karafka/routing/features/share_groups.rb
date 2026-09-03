# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      # Share-group-specific routing features (KIP-932 / Queues for Kafka). Sibling of
      # {Features::ConsumerGroups}. It is empty for now - individual share-group routing features
      # (acknowledgment, delayed release, lock extension, share-group DLQ, jobs builder, poll
      # interval, ...) will be added here as the KIP-932 work progresses.
      module ShareGroups
      end
    end
  end
end
