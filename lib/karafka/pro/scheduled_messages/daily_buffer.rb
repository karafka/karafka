# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
        # @yieldparam [Integer, Karafka::Messages::Message] epoch of the message and the message
        #   itself
        #
        # @note We yield epoch alongside of the message so we do not have to extract it several
        #   times later on. This simplifies the API
        def for_dispatch
          dispatch = Time.now.to_i

          @accu.each_value do |epoch, message|
            next unless epoch <= dispatch

            yield(epoch, message)
          end
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
