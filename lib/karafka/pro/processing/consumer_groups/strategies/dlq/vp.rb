# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

module Karafka
  module Pro
    module Processing
      # Consumer-group-specific Pro processing components (driven by rebalance callbacks and
      # partition ticks). Parallel `ShareGroups` will live next to this namespace once KIP-932
      # lands.
      module ConsumerGroups
        module Strategies
          module Dlq
            # Dead Letter Queue enabled
            # Virtual Partitions enabled
            #
            # In general because we collapse processing in virtual partitions to one on errors,
            # there is no special action that needs to be taken because we warranty that even with
            # VPson errors a retry collapses into a single state and from this single state we can
            # mark as consumed the message that we are moving to the DLQ.
            module Vp
              # Features for this strategy
              FEATURES = %i[
                dead_letter_queue
                virtual_partitions
              ].freeze

              include Strategies::Dlq::Default
              include Strategies::Vp::Default

              # Runs the DLQ strategy and based on it it performs certain operations
              #
              # In case of `:skip` and `:dispatch` will run the exact flow provided in a block
              # In case of `:retry` always `#retry_after_pause` is applied
              def apply_dlq_flow
                # Process-critical errors are never dispatched or skipped regardless of the
                # strategy outcome: the retry pause protects the partition during the critical
                # shutdown and the failed batch is redelivered after the restart.
                # We consult `errors_tracker.last` (not the per-consumer consumption cause used
                # by the OSS strategies, which have no tracker) because it is exactly what the
                # DLQ strategy callable below receives - this guard judges the same evidence as
                # the strategy it overrides. The tracker is cleared at attempt zero, so `last`
                # is always the most recent failure of the current failure streak
                if critical_error?(errors_tracker.last)
                  retry_after_pause

                  return
                end

                # With virtual partitions, a dispatch/skip decision is never made on a
                # non-collapsed (parallel) run. The deciding consumer operates only on its own
                # virtual partition subset there: the skippable message would be selected from
                # an arbitrary subset and the dispatch marking would commit offsets of messages
                # other virtual partitions never processed. The failure already requested a
                # collapse, so we retry and let the decision happen on the collapsed, linear
                # flow where it is deterministic
                if topic.virtual_partitions? && !collapsed?
                  retry_after_pause

                  return
                end

                flow, target_topic = topic.dead_letter_queue.strategy.call(errors_tracker, attempt)

                case flow
                when :retry
                  retry_after_pause

                  return
                when :skip
                  @_dispatch_to_dlq = false
                when :dispatch
                  @_dispatch_to_dlq = true
                  # Use custom topic if it was returned from the strategy
                  @_dispatch_to_dlq_topic = target_topic || topic.dead_letter_queue.topic
                else
                  raise Karafka::UnsupportedCaseError, flow
                end

                yield

                # We reset the pause to indicate we will now consider it as "ok".
                coordinator.pause_tracker.reset

                # Always backoff after DLQ dispatch even on skip to prevent overloads on errors
                pause(seek_offset, nil, false)
              ensure
                @_dispatch_to_dlq_topic = nil
              end
            end
          end
        end
      end
    end
  end
end
