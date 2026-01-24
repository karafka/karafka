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
        # Filtering related init strategies
        module Ftr
          # Filtering enabled
          # VPs enabled
          #
          # VPs should operate without any problems with filtering because virtual partitioning
          # happens on the limited set of messages and collective filtering applies the same
          # way as for default cases
          module Vp
            # Filtering + VPs
            FEATURES = %i[
              filtering
              virtual_partitions
            ].freeze

            include Strategies::Vp::Default
            include Strategies::Ftr::Default
          end
        end
      end
    end
  end
end
