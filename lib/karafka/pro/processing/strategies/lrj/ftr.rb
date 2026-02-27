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
          # Filtering enabled
          # Long-Running Job enabled
          #
          # In general aside from throttling this one will behave the same way as the Lrj
          module Ftr
            include Strategies::Ftr::Default
            include Strategies::Lrj::Default

            # Features for this strategy
            FEATURES = %i[
              filtering
              long_running_job
            ].freeze

            # LRJ standard flow after consumption with potential throttling on success
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  # Manual pausing has the highest priority
                  return if coordinator.manual_pause?

                  # It's not a MoM, so for successful we need to mark as consumed
                  mark_as_consumed(last_group_message) unless revoked?

                  # If still not revoked and was throttled, we need to apply throttling logic
                  if coordinator.filtered? && !revoked?
                    handle_post_filtering

                    # handle_post_filtering may pause (throttle) or seek+resume on its own,
                    # but when the filter action is :skip, the LRJ pause is still active and
                    # must be lifted explicitly to avoid a permanent partition freeze.
                    resume if coordinator.filter.action == :skip
                  elsif !revoked? && !coordinator.manual_seek?
                    # If not revoked and not throttled, we move to where we were suppose to and
                    # resume
                    seek(seek_offset, false, reset_offset: false)
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
