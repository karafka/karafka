# frozen_string_literal: true

module Karafka
  module Routing
    class Topics
      # Share-group topic (KIP-932 / Queues for Kafka).
      #
      # It inherits only the mode-agnostic {Topics::Base} behavior and deliberately does **not**
      # inherit {Karafka::Routing::Topic}, so consumer-group routing features (which are prepended
      # onto `Routing::Topic`) do not leak onto share topics. Share-group specific routing features
      # will attach here once they land.
      class ShareGroupTopic < Base
      end
    end
  end
end
