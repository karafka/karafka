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
          # - DLQ
          # - Ftr
          module Ftr
            include Strategies::Ftr::Default
            include Strategies::Dlq::Default

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              filtering
            ].freeze

            # DLQ flow is standard here, what is not, is the success component where we need to
            # take into consideration the filtering
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                return if revoked?

                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if coordinator.manual_pause?

                  mark_as_consumed(last_group_message)

                  handle_post_filtering
                else
                  apply_dlq_flow do
                    dispatch_if_needed_and_mark_as_consumed
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
