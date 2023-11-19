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
        # @note We cache insights on the consumer, as in some scenarios we may no longer have them
        #   inside the Tracker, for example under involuntary revocation, incoming statistics may
        #   no longer have lost partition insights. Since we want to be consistent during single
        #   batch operations, we want to ensure, that if we have insights they are available
        #   throughout the whole processing.
        def insights
          insights = Tracker.find(topic, partition)

          # If we no longer have new insights but we still have them locally, we can use them
          return @insights if @insights && insights.empty?
          # If insights are still the same, we can use them
          return @insights if @insights.equal?(insights)

          # If we've received new insights that are not empty, we can cache them
          @insights = insights
        end

        # @return [Boolean] true if there are insights to work with, otherwise false
        def insights?
          !insights.empty?
        end

        alias statistics insights
        alias statistics? insights?
        alias inline_insights insights
        alias inline_insights? insights?
      end
    end
  end
end
