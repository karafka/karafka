# frozen_string_literal: true

module Karafka
  module Routing
    # Legacy flat alias for the canonical {Karafka::Routing::ShareGroups::Group}, mirroring
    # {Karafka::Routing::ConsumerGroup}. Provided for symmetry and convenience. New code should
    # reference `ShareGroups::Group`. Scheduled for retirement in Karafka 3.0.
    ShareGroup = ShareGroups::Group
  end
end
