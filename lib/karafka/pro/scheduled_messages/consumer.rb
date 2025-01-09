# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module ScheduledMessages
      # Consumer that coordinates scheduling of messages when the time comes
      class Consumer < ::Karafka::BaseConsumer
        # Prepares the initial state of all stateful components
        def initialized
          clear!
          # Max epoch is always moving forward with the time. Never backwards, hence we do not
          # reset it at all.
          @max_epoch = MaxEpoch.new
          @state = State.new(nil)
        end

        # Processes messages and runs dispatch (via tick) if needed
        def consume
          return if reload!

          messages.each do |message|
            SchemaValidator.call(message)
            process_message(message)
          end

          @states_reporter.call

          eofed if eofed?

          # Unless given day data is fully loaded we should not dispatch any notifications nor
          # should we mark messages.
          return unless @state.loaded?

          tick

          # Despite the fact that we need to load the whole stream once a day we do mark.
          # We mark as consumed for two main reasons:
          #   - by marking we can indicate to Web UI and other monitoring tools that we have a
          #     potential real lag with loading schedules in case there would be a lot of messages
          #     added to the schedules topic
          #   - we prevent a situation where there is no notion of this consumer group in the
          #     reporting, allowing us to establish "presence"
          mark_as_consumed(messages.last)
        end

        # Runs end of file operations
        def eofed
          return if reload!

          # If end of the partition is reached, it always means all data is loaded
          @state.loaded!
          @states_reporter.call
        end

        # Performs periodic operations when no new data is provided to the topic partition
        def tick
          return if reload!

          # We should not dispatch any data until the whole state is loaded. We need to make sure,
          # that all tombstone events are loaded not to duplicate dispatches
          return unless @state.loaded?

          keys = []
          epochs = []

          # We first collect all the data for dispatch and then dispatch and **only** after
          # dispatch that is sync is successful we remove those messages from the daily buffer
          # and update the max epoch. Since only the dispatch itself is volatile and can crash
          # with timeouts, etc, we need to be sure it wen through prior to deleting those messages
          # from the daily buffer. That way we ensure the at least once delivery and in case of
          # a transactional producer, exactly once delivery.
          @daily_buffer.for_dispatch do |epoch, message|
            epochs << epoch
            keys << message.key
            @dispatcher << message
          end

          @dispatcher.flush

          @max_epoch.update(epochs.max)

          keys.each { |key| @daily_buffer.delete(key) }

          @states_reporter.call
        end

        private

        # Takes each message and adds it to the daily accumulator if needed or performs other
        # accumulator and time related per-message operations.
        # @param message [Karafka::Messages::Message]
        def process_message(message)
          # If we started to receive messages younger than the moment we created the consumer for
          # the given day, it means we have loaded all the history and we are no longer in the
          # loading phase.
          if message.timestamp.to_i > @today.created_at
            @state.loaded!
            tags.add(:state, @state.to_s)
          end

          # If this is a schedule message we need to check if this is for today. Tombstone events
          # are always considered immediate as they indicate, that a message with a given key
          # was already dispatched or that user decided not to dispatch and cancelled the dispatch
          # via tombstone publishing.
          if message.headers['schedule_source_type'] == 'schedule'
            time = message.headers['schedule_target_epoch']

            # Do not track historical below today as those will be reflected in the daily buffer
            @tracker.track(message) if time >= @today.starts_at

            if time > @today.ends_at || time < @max_epoch.to_i
              # Clean the message immediately when not needed (won't be scheduled) to preserve
              # memory
              message.clean!

              return
            end
          end

          # Add to buffer all tombstones and messages for the same day
          @daily_buffer << message
        end

        # Moves the offset back and re-seeks and reloads the current day not dispatched assignments
        def reload!
          # If this is a new assignment we always need to seek from beginning to load the data
          if @state.fresh?
            clear!
            seek(0)

            return true
          end

          # Unless state is loaded we do not do anything more because we're in the loading process
          return false unless @state.loaded?

          # If day has ended we reload and start new day with new schedules
          if @today.ended?
            clear!
            seek(0)

            return true
          end

          false
        end

        # Resets all buffers and states so we can start a new day with a clean slate
        # We can fully recreate the dispatcher because any undispatched messages will be dispatched
        # with the new day dispatcher after it is reloaded.
        def clear!
          @daily_buffer = DailyBuffer.new
          @today = Day.new
          @tracker = Tracker.new
          @state = State.new(false)
          @dispatcher = config.dispatcher_class.new(topic.name, partition)
          @states_reporter = Helpers::IntervalRunner.new do
            @tracker.today = @daily_buffer.size
            @tracker.state = @state.to_s

            @dispatcher.state(@tracker)
          end

          tags.add(:state, @state.to_s)
        end

        # @return [Karafka::Core::Configurable::Node] Schedules config node
        def config
          @config ||= Karafka::App.config.scheduled_messages
        end
      end
    end
  end
end
