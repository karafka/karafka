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
        module Aj
          # ActiveJob enabled
          # DLQ enabled
          # Long-Running Job enabled
          # Manual offset management enabled
          #
          # This case is a bit of special. Please see the `AjDlqMom` for explanation on how the
          # offset management works in this case.
          module DlqLrjMom
            include Strategies::Default
            include Strategies::Dlq::Default
            include Strategies::Aj::LrjMom

            # Features for this strategy
            FEATURES = %i[
              active_job
              dead_letter_queue
              long_running_job
              manual_offset_management
            ].freeze

            # We cannot use a VP version of this, because non-VP can early stop on shutdown
            def handle_after_consume
              coordinator.on_finished do
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  # no need to check for manual seek because AJ consumer is internal and
                  # fully controlled by us
                  seek(seek_offset, false, reset_offset: false) unless revoked?

                  resume
                else
                  apply_dlq_flow do
                    skippable_message, = find_skippable_message
                    dispatch_to_dlq(skippable_message) if dispatch_to_dlq?
                    mark_dispatched_to_dlq(skippable_message)
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
