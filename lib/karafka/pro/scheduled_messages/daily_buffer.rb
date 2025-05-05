# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
          schedule = message.headers['schedule_source_type'] == 'schedule'

          key = message.key

          if schedule
            epoch = message.headers['schedule_target_epoch']
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

          selected
            .sort_by!(&:first)
            .each { |_, message| yield(message) }
        end

        # Removes given key from the accumulator
        # @param key [String] key to remove
        def delete(key)
          @accu.delete(key)
        end
      end
    end
  end
end
