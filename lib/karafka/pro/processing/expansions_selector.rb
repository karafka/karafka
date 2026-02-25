# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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
