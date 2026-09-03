# frozen_string_literal: true

module Karafka
  module Routing
    # Legacy flat alias for the canonical {Karafka::Routing::Groups::ConsumerGroup}. Kept for
    # backwards compatibility because it is widely referenced and is de-facto public API. New code
    # should reference `Groups::ConsumerGroup`. Scheduled for retirement in Karafka 3.0.
    ConsumerGroup = Groups::ConsumerGroup
  end
end
