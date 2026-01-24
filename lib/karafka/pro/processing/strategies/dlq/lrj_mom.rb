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
          # Strategy for supporting DLQ with Mom and LRJ enabled
          module LrjMom
            # This strategy needs to pause and revoke same way as DlqLrj but without the offset
            # management
            include Strategies::Dlq::Lrj

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              long_running_job
              manual_offset_management
            ].freeze

            # LRJ standard flow after consumption with DLQ dispatch and no offset management
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
                  apply_dlq_flow do
                    return resume if revoked?

                    skippable_message, _marked = find_skippable_message
                    dispatch_to_dlq(skippable_message) if dispatch_to_dlq?

                    if mark_after_dispatch?
                      mark_dispatched_to_dlq(skippable_message)
                    else
                      self.seek_offset = skippable_message.offset + 1
                    end
                  end
                end
              end
            end

            # @return [Boolean] should we mark given message as consumed after dispatch. For
            #  MOM strategies if user did not explicitly tell us to mark, we do not mark. Default
            #  is `nil`, which means `false` in this case. If user provided alternative value, we
            #  go with it.
            #
            # @note Please note, this is the opposite behavior than in case of AOM strategies.
            def mark_after_dispatch?
              return false if topic.dead_letter_queue.mark_after_dispatch.nil?

              topic.dead_letter_queue.mark_after_dispatch
            end
          end
        end
      end
    end
  end
end
