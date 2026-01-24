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
      module Strategies
        module Dlq
          # Dead Letter Queue enabled
          # Virtual Partitions enabled
          #
          # In general because we collapse processing in virtual partitions to one on errors, there
          # is no special action that needs to be taken because we warranty that even with VPs
          # on errors a retry collapses into a single state and from this single state we can
          # mark as consumed the message that we are moving to the DLQ.
          module Vp
            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              virtual_partitions
            ].freeze

            include Strategies::Dlq::Default
            include Strategies::Vp::Default
          end
        end
      end
    end
  end
end
