# frozen_string_literal: true

module Karafka
  module Processing
    # Namespace of the Inline Insights feature "non routing" related components
    #
    # @note We use both `#insights` because it is the feature name but also `#statistics` to make
    #   it consistent with the fact that we publish and operate on statistics. User can pick
    #   whichever name they prefer.
    module InlineInsights
      # Module that adds extra methods to the consumer that allow us to fetch the insights
      module Consumer
        # @return [Hash] empty hash or hash with given partition insights if already present
        def insights
          Tracker.find(topic, partition)
        end

        # @return [Boolean] true if there are insights to work with, otherwise false
        def insights?
          Tracker.exists?(topic, partition)
        end

        def statistics
          insights
        end

        def statistics?
          insights?
        end
      end
    end
  end
end
