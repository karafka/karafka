# frozen_string_literal: true

module Karafka
  module Processing
    # Selector of appropriate topic setup based features enhancements.
    #
    # Those expansions to the consumer API are NOT about the flow of processing. For this we have
    # strategies. Those are suppose to provide certain extra APIs that user can use to get some
    # extra non-flow related functionalities.
    class ExpansionsSelector
      # @param topic [Karafka::Routing::Topic] topic with settings based on which we find
      #   expansions
      # @return [Array<Module>] modules with proper expansions we're suppose to use to enhance the
      #   consumer
      def find(topic)
        expansions = []
        expansions << Processing::InlineInsights::Consumer if topic.inline_insights?
        expansions
      end
    end
  end
end
