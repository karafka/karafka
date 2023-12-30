# frozen_string_literal: true

module Karafka
  module Pro
    module Processing
      # Pro selector of appropriate topic setup based features enhancements.
      class ExpansionsSelector < Karafka::Processing::ExpansionsSelector
        # @param topic [Karafka::Routing::Topic] topic with settings based on which we find
        #   expansions
        # @return [Array<Module>] modules with proper expansions we're suppose to use to enhance
        #   the consumer
        def find(topic)
          # Start with the non-pro expansions
          expansions = super
          expansions << Pro::Processing::OffsetMetadata::Consumer if topic.offset_metadata?
          expansions
        end
      end
    end
  end
end
