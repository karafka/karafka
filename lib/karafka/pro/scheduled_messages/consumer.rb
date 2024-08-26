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
      class Consumer < ::Karafka::BaseConsumer
        def consume
          @daily_messages = nil if @end_of_day && @end_of_day < Time.now.to_i

          # When no daily messages it means we should seek back and replay log from start
          unless @daily_messages
            @daily_messages = {}
            @bootstrapped = false
            @end_of_day = nil
            # If we have a previous commit stored, we can safely assume, all previous messages were
            # dispatched
            @max_dispatched_time = offset_metadata ? offset_metadata[:last_dispatched_time] : -1

            now = Time.now.utc
            start_of_day = Time.utc(now.year, now.month, now.day).to_i
            @end_of_day = start_of_day + 86_399
            # Buffor for events that could have been dispatched when recovering, etc. Anything that
            # will have a past date and is not with a tombstone, will be dispatched
            @end_of_prev_day = start_of_day - 86_399

            seek(0)

            return
          end

          messages.each do |message|
            next if message.headers['future-type'] == 'recovery'

            time = message.headers['future-dispatch-at'].to_i
            tombstone = message.raw_payload.nil?

            # Not for today
            next if time > @end_of_day
            # older than one day, we skip as below the graceful period
            next if time < @end_of_prev_day && !tombstone
            # Skip if the stored metadata time indicates, we've already seen and dispatched messages with
            # this time. -10 is a grace period to compensate for close-future network spikes
            next if time < @max_dispatched_time - 10 && !tombstone

            key = message.key

            if tombstone
              @daily_messages.delete(key)
            else
              @daily_messages[key] = [time, message]
            end
          end

          if @bootstrapped
            messages.each do |message|
              next unless message.raw_payload.nil?

              mark_as_consumed(message, @max_dispatched_time.to_s)
            end
          else
            messages.each do |message|
              time = message.headers['future-dispatch-at'].to_i
              @bootstrapped = true if time > (@max_dispatched_time + 10) && @max_dispatched_time != -1
            end
          end

          eofed if eofed?

          tick if @bootstrapped
        end

        def eofed
          if @daily_messages
            @bootstrapped = true
          else
            Karafka.producer.produce_async(
              topic: topic.name,
              partition: partition,
              payload: '',
              key: 'future-recovery',
              headers: { 'future-type' => 'recovery' }
            )

            return
          end
        end

        def tick
          return unless @bootstrapped
          return unless @daily_messages

          dispatch = Time.now.to_i
          dispatched_times = []

          @daily_messages.each do |key, details|
            time, message = details

            next unless time <= dispatch

            p "Dispatching #{message.offset}"
            Karafka.producer.produce_async(topic: topic.name, partition: partition, payload: nil, key: message.key)
            @daily_messages.delete(key)
            dispatched_times << time
          end

          return if dispatched_times.empty?

          @max_dispatched_time = dispatched_times.max > @max_dispatched_time ? dispatched_times.max : @max_dispatched_time
        end
      end
    end
  end
end
