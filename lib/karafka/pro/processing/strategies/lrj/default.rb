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
          module Default
            include Strategies::Default

            # Pause for tops 31 years
            MAX_PAUSE_TIME = 1_000_000_000_000

            # Features for this strategy
            FEATURES = %i[
              long_running_job
            ].freeze

            # We always need to pause prior to doing any jobs for LRJ
            def handle_before_schedule_consume
              super

              # This ensures that when running LRJ with VP, things operate as expected run only
              # once for all the virtual partitions collectively
              coordinator.on_enqueued do
                # Pause and continue with another batch in case of a regular resume.
                # In case of an error, the `#retry_after_pause` will move the offset to the first
                # message out of this batch.
                pause(:consecutive, MAX_PAUSE_TIME, false)
              end
            end

            # LRJ standard flow after consumption
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if coordinator.manual_pause?

                  mark_as_consumed(last_group_message) unless revoked?

                  unless revoked? || coordinator.manual_seek?
                    seek(seek_offset, false, reset_offset: false)
                  end

                  resume
                else
                  # If processing failed, we need to pause
                  # For long running job this will overwrite the default never-ending pause and
                  # will cause the processing to keep going after the error backoff
                  retry_after_pause
                end
              end
            end

            # We do not un-pause on revokations for LRJ
            def handle_revoked
              coordinator.on_revoked do
                # We do not want to resume on revocation in case of a LRJ.
                # For LRJ we resume after the successful processing or do a backoff pause in case
                # of a failure. Double non-blocking resume could cause problems in coordination.
                coordinator.revoke
              end

              monitor.instrument('consumer.revoke', caller: self)
              monitor.instrument('consumer.revoked', caller: self) do
                revoked
              end
            ensure
              coordinator.decrement(:revoked)
            end

            # Allows for LRJ to synchronize its work. It may be needed because LRJ can run
            # lifecycle events like revocation while the LRJ work is running and there may be a
            # need for a critical section.
            def synchronize(&)
              coordinator.shared_mutex.synchronize(&)
            end
          end
        end
      end
    end
  end
end
