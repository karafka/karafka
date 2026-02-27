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
        module Lrj
          # Long-Running Job enabled
          # Filtering enabled
          # Manual offset management enabled
          #
          # It is really similar to the Lrj::Ftr but we do not mark anything as consumed
          module FtrMom
            include Strategies::Lrj::Ftr

            # Features for this strategy
            FEATURES = %i[
              filtering
              long_running_job
              manual_offset_management
            ].freeze

            # LRJ standard flow after consumption with potential filtering on success
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  # Manual pausing has the highest priority
                  return if coordinator.manual_pause?

                  # If still not revoked and was throttled, we need to apply filtering logic
                  if coordinator.filtered? && !revoked?
                    handle_post_filtering

                    # handle_post_filtering may pause (throttle) or seek+resume on its own,
                    # but when the filter action is :skip, the LRJ pause is still active and
                    # must be lifted explicitly to avoid a permanent partition freeze.
                    resume if coordinator.filter.action == :skip
                  elsif !revoked? && !coordinator.manual_seek?
                    # If not revoked and not throttled, we move to where we were suppose to and
                    # resume
                    seek(last_group_message.offset + 1, false, reset_offset: false)
                    resume
                  else
                    resume
                  end
                else
                  # If processing failed, we need to pause
                  # For long running job this will overwrite the default never-ending pause and
                  # will cause the processing to keep going after the error backoff
                  retry_after_pause
                end
              end
            end
          end
        end
      end
    end
  end
end
