# frozen_string_literal: true

# Backwards-compatible alias kept for external gems (e.g. karafka-testing < 2.6) that reference
# the old, un-namespaced constant. Will be removed in Karafka 3.0.
module Karafka
  module Processing
    CoordinatorsBuffer = ConsumerGroups::CoordinatorsBuffer
  end
end
