# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
          expansions << Pro::Processing::PeriodicJob::Consumer if topic.periodic_job?
          expansions
        end
      end
    end
  end
end
