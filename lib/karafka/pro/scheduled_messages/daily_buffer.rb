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
    module ScheduledMessages
      # Stores schedules for the current day and gives back those that should be dispatched
      # We do not use min-heap implementation and just a regular hash because we want to be able
      # to update the schedules based on the key as well as remove the schedules in case it would
      # be cancelled. While removals could be implemented, updates with different timestamp would
      # be more complex. At the moment a lookup of 8 640 000 messages (100 per second) takes
      # up to 1.5 second, thus it is acceptable. Please ping me if you encounter performance
      # issues with this naive implementation so it can be improved.
      class DailyBuffer
        # Initializes the daily buffer with empty accumulator
        def initialize
          @accu = {}
        end

        # @return [Integer] number of elements to schedule today
        def size
          @accu.size
        end

        # Adds message to the buffer or removes the message from the buffer if it is a tombstone
        # message for a given key
        #
        # @param message [Karafka::Messages::Message]
        #
        # @note Only messages for a given day should be added here.
        def <<(message)
          # Non schedule are only tombstones and cancellations
          schedule = message.headers["schedule_source_type"] == "schedule"

          key = message.key

          if schedule
            epoch = message.headers["schedule_target_epoch"]
            @accu[key] = [epoch, message]
          else
            @accu.delete(key)
          end
        end

        # Yields messages that should be dispatched (sent) to Kafka
        #
        # @yieldparam [Karafka::Messages::Message] messages to be dispatched sorted from the once
        #   that are the oldest (lowest epoch)
        def for_dispatch
          dispatch = Time.now.to_i

          selected = []

          @accu.each_value do |epoch, message|
            next unless epoch <= dispatch

            selected << [epoch, message]
          end

          # When epoch is of the same value for multiple messages to be dispatched, we also sort
          # on the offset to make sure that earlier messages are dispatched prior to newer
          selected.sort! do |pck1, pck2|
            cmp = pck1[0] <=> pck2[0]

            cmp.zero? ? pck1[1].offset <=> pck2[1].offset : cmp
          end

          selected.each { |_, message| yield(message) }
        end

        # Removes the schedule entry identified by the given key from the daily buffer
        # @param key [String]
        def delete(key)
          @accu.delete(key)
        end
      end
    end
  end
end
