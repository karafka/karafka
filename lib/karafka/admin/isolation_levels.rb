# frozen_string_literal: true

module Karafka
  class Admin
    # Isolation level constants for Kafka operations.
    #
    # Controls whether a query returns the high-watermark (includes messages from uncommitted
    # or in-flight transactions) or the Last Stable Offset (excludes them).
    #
    # For non-transactional topics both values give the same result.
    module IsolationLevels
      # Default. Returns the high-watermark offset, which includes messages written by
      # producers that have not yet committed (or aborted) their transaction.
      READ_UNCOMMITTED = Rdkafka::Bindings::RD_KAFKA_ISOLATION_LEVEL_READ_UNCOMMITTED

      # Returns the Last Stable Offset (LSO): the highest offset that a READ_COMMITTED
      # consumer would actually see. Use this when computing lag on topics produced with
      # transactional producers, otherwise the high-watermark overstates lag.
      READ_COMMITTED = Rdkafka::Bindings::RD_KAFKA_ISOLATION_LEVEL_READ_COMMITTED
    end
  end
end
