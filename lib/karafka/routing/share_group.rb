# frozen_string_literal: true

module Karafka
  module Routing
    # Legacy flat alias for the canonical {Karafka::Routing::Groups::ShareGroup}, mirroring
    # {Karafka::Routing::ConsumerGroup}. Provided for symmetry and convenience. New code should
    # reference `Groups::ShareGroup`. Scheduled for retirement in Karafka 3.0.
    ShareGroup = Groups::ShareGroup
  end
end
