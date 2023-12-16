# frozen_string_literal: true

module Karafka
  module Processing
    # Namespace of the Inline Insights feature "non routing" related components
    #
    # @note We use both `#insights` because it is the feature name but also `#statistics` to make
    #   it consistent with the fact that we publish and operate on statistics. User can pick
    #   whichever name they prefer.
    module InlineInsights
    end
  end
end
