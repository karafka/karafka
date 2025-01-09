# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
          expansions << Pro::Processing::Piping::Consumer
          expansions << Pro::Processing::OffsetMetadata::Consumer if topic.offset_metadata?
          expansions << Pro::Processing::AdaptiveIterator::Consumer if topic.adaptive_iterator?
          expansions << Pro::Processing::PeriodicJob::Consumer if topic.periodic_job?
          expansions
        end
      end
    end
  end
end
