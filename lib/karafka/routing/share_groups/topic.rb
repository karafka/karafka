# frozen_string_literal: true

module Karafka
  module Routing
    module ShareGroups
      # Share-group topic (KIP-932 / Queues for Kafka).
      #
      # It inherits only the mode-agnostic {Topics::Base} behavior and deliberately does **not**
      # inherit {ConsumerGroups::Topic}, so consumer-group routing features (which are prepended
      # onto the consumer topic) do not leak onto share topics. Share-group specific routing
      # features attach here (via a feature's `ShareTopic` module) once they land.
      class Topic < Topics::Base
      end
    end
  end
end
