# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module RecurringTasks
      # Consumer responsible for management of the recurring tasks and their execution
      # There are some assumptions made here that always need to be satisfied:
      #   - we only run schedules that are of same or newer version
      #   - we always mark as consumed in such a way, that the first message received after
      #     assignment (if any) is a state
      class Consumer < ::Karafka::BaseConsumer
        # @param args [Array] all arguments accepted by the consumer
        def initialize(*args)
          super
          @executor = Executor.new
        end

        def consume
          # There is nothing we can do if we operate on a newer schedule. In such cases we should
          # just wait and re-raise error hoping someone will notice or that this will be
          # reassigned to a process with newer schedule
          raise(Errors::IncompatibleScheduleError) if @executor.incompatible?

          messages.each do |message|
            payload = message.payload
            type = payload[:type]

            case type
            when 'schedule'
              # If we're replaying data, we need to record the most recent stored state, so we
              # can use this data to fully initialize the scheduler
              @executor.update_state(payload) if @executor.replaying?

              # If this is first message we cannot mark it on the previous offset
              next if message.offset.zero?

              # We always mark as consumed in such a way, that when replaying, we start from a
              # schedule state message. This makes it easier to recover.
              mark_as_consumed Karafka::Messages::Seek.new(
                topic.name,
                partition,
                message.offset - 1
              )
            when 'command'
              @executor.apply_command(payload)

              next if @executor.replaying?

              # Execute on each incoming command to have nice latency but only after replaying
              # During replaying we should not execute because there may be more state changes
              # that collectively have a different outcome
              @executor.call
            else
              raise ::Karafka::Errors::UnsupportedCaseError, type
            end
          end

          eofed if eofed?
        end

        # Starts the final replay process if we reached eof during replaying
        def eofed
          # We only mark as replayed if we were replaying in the first place
          # If already replayed, nothing to do
          return unless @executor.replaying?

          @executor.replay
        end

        # Runs the cron execution if all good.
        def tick
          # Do nothing until we fully recover the correct state
          return if @executor.replaying?

          # If the state is incompatible, we can only raise an error.
          # We do it here and in the `#consume` so the pause-retry kicks in basically reporting
          # on this issue once every minute. That way user should not miss this.
          # We use seek to move so we can achieve a pause of 60 seconds in between consecutive
          # errors instead of on each tick because it is much more frequent.
          if @executor.incompatible?
            if messages.empty?
              raise Errors::IncompatibleScheduleError
            else
              return seek(messages.last.offset - 1)
            end
          end

          # If all good and compatible we can execute the recurring tasks
          @executor.call
        end
      end
    end
  end
end
