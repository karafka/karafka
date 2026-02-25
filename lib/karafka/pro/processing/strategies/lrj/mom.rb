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
        # Namespace for all the LRJ starting strategies
        module Lrj
          # Long-Running Job enabled
          # Manual offset management enabled
          module Mom
            include Strategies::Default

            # Features for this strategy
            FEATURES = %i[
              long_running_job
              manual_offset_management
            ].freeze

            # We always need to pause prior to doing any jobs for LRJ
            def handle_before_schedule_consume
              super

              # This ensures that when running LRJ with VP, things operate as expected run only
              # once for all the virtual partitions collectively
              coordinator.on_enqueued do
                pause(:consecutive, Strategies::Lrj::Default::MAX_PAUSE_TIME, false)
              end
            end

            # No offset management, aside from that typical LRJ
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if coordinator.manual_pause?

                  unless revoked? || coordinator.manual_seek?
                    seek(last_group_message.offset + 1, false, reset_offset: false)
                  end

                  resume
                else
                  retry_after_pause
                end
              end
            end

            # We do not un-pause on revokations for LRJ
            def handle_revoked
              coordinator.on_revoked do
                coordinator.revoke
              end

              monitor.instrument("consumer.revoke", caller: self)
              monitor.instrument("consumer.revoked", caller: self) do
                revoked
              end
            ensure
              coordinator.decrement(:revoked)
            end
          end
        end
      end
    end
  end
end
