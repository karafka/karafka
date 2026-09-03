# frozen_string_literal: true

module Karafka
  module Routing
    # Legacy flat alias for the canonical {Karafka::Routing::Topics::ConsumerGroupTopic}. Kept for
    # backwards compatibility because it is widely referenced - and because consumer-group routing
    # features attach to it by this name - and is de-facto public API. New code should reference
    # `Topics::ConsumerGroupTopic`. Scheduled for retirement in Karafka 3.0.
    Topic = Topics::ConsumerGroupTopic
  end
end
