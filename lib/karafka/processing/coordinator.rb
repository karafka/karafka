# frozen_string_literal: true

# Backwards-compatible alias kept for external code that references the old, un-namespaced
# constant. Will be removed in Karafka 3.0.
module Karafka
  module Processing
    # @see ConsumerGroups::Coordinator
    Coordinator = ConsumerGroups::Coordinator
  end
end
