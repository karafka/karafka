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
      # Namespace for adaptive iterator consumer components
      module AdaptiveIterator
        # Consumer enhancements needed to wrap the batch iterator for adaptive iterating
        # It automatically marks as consumed, ensures that we do not reach `max.poll.interval.ms`
        # and does other stuff to simplify user per-message processing
        module Consumer
          # @param args [Array] anything accepted by `Karafka::Messages::Messages#each`
          def each(*args)
            adi_config = topic.adaptive_iterator

            tracker = Tracker.new(
              adi_config.safety_margin,
              coordinator.last_polled_at,
              topic.subscription_group.kafka.fetch(:"max.poll.interval.ms")
            )

            messages.each(*args) do |message|
              # Always stop if we've lost the assignment
              return if revoked?
              # No automatic marking risk when mom is enabled so we can fast stop
              return if Karafka::App.done? && topic.manual_offset_management?

              # Seek request on done will allow us to stop without marking the offset when user had
              # the automatic offset marking. This should not be a big network traffic issue for
              # the end user as we're stopping anyhow but should improve shutdown time
              if tracker.enough? || Karafka::App.done?
                # Enough means we no longer have time to process more data without polling as we
                # risk reaching max poll interval. Instead we seek and we will poll again soon.
                seek(message.offset, reset_offset: true)

                return
              end

              tracker.track { yield(message) }

              # Clean if this is what user configured
              message.clean! if adi_config.clean_after_yielding?

              public_send(adi_config.marking_method, message)
            end
          end
        end
      end
    end
  end
end
