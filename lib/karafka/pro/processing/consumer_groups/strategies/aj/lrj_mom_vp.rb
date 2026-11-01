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
      module ConsumerGroups
        module Strategies
          module Aj
            # - ActiveJob enabled
            # - Long-Running Job enabled
            # - Manual offset management enabled
            # - Virtual Partitions enabled
            module LrjMomVp
              include Strategies::Default
              include Strategies::Vp::Default

              # Features for this strategy
              FEATURES = %i[
                active_job
                long_running_job
                manual_offset_management
                virtual_partitions
              ].freeze

              # No actions needed for the standard flow here
              def handle_before_schedule_consume
                super

                coordinator.on_enqueued do
                  pause(:consecutive, Strategies::Lrj::Default::MAX_PAUSE_TIME, false)
                end
              end

              # Standard flow without any features
              def handle_after_consume
                coordinator.on_finished do |last_group_message|
                  if coordinator.success?
                    coordinator.pause_tracker.reset

                    mark_as_consumed(last_group_message) unless revoked?

                    # no need to check for manual seek because AJ consumer is internal and
                    # fully controlled by us
                    seek(seek_offset, false, reset_offset: false) unless revoked?

                    resume
                  else
                    # If processing failed, we need to pause
                    # For long running job this will overwrite the default never-ending pause and
                    # will cause the processing to keep going after the error backoff
                    retry_after_pause
                  end
                end
              end

              # LRJ cannot resume here. Only in handling the after consumption
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

              # Pauses the current topic partition and holds the pause tracker until the client
              # pause lands
              #
              # @param offset [Integer, Symbol] offset from which we want to restart the
              #   processing or `:consecutive` if we want to pause and continue without changing
              #   the consecutive offset (cursor position)
              # @param timeout [Integer, nil] how long in milliseconds do we want to pause or nil
              #   to use the default exponential pausing strategy defined for retries
              # @param manual_pause [Boolean] Flag to differentiate between user pause and
              #   system/strategy based pause
              #
              # @note Same as `Lrj::Default#pause`, which this strategy does not include
              def pause(offset, timeout = nil, manual_pause = true)
                pause_tracker = coordinator.pause_tracker
                timeout ||= pause_tracker.backoff_interval

                offset = nil if offset == :consecutive

                pause_tracker.hold

                begin
                  client.pause(topic.name, partition, offset, timeout)
                ensure
                  pause_tracker.pause(timeout)
                end

                # Indicate, that user took a manual action of pausing
                coordinator.manual_pause if manual_pause

                monitor.instrument(
                  "consumer.consuming.pause",
                  caller: self,
                  manual: manual_pause,
                  topic: topic.name,
                  partition: partition,
                  subscription_group: topic.subscription_group,
                  offset: offset,
                  timeout: timeout,
                  attempt: attempt
                )
              end
            end
          end
        end
      end
    end
  end
end
