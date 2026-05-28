# frozen_string_literal: true

module Karafka
  module Connection
    class Client
      module PollingStrategies
        # Polling strategy for consumers that use enable.partition.eof. Uses the single-message
        # poll path which returns immediately on any event including EOF, preserving the
        # low-latency yielding that EOF consumers depend on.
        #
        # poll_batch (rd_kafka_consume_batch_queue) sets abs_timeout once at call time and keeps
        # waiting after an EOF arrives until either max_items fills or the timeout expires. The
        # old kafka.poll (rd_kafka_consumer_poll) returns immediately on any event, so this
        # strategy restores that behaviour for EOF consumers.
        module Eof
          private

          # @param time_poll [Karafka::TimeTrackers::Poll] poll time tracker
          def batch_poll_inner(time_poll)
            loop do
              time_poll.start

              break if time_poll.exceeded?
              break if @buffer.size >= @subscription_group.max_messages

              response = poll(time_poll.remaining)

              @buffer.polled

              case response
              when :tick_time
                nil
              when Hash
                @buffer.eof(response[:topic], response[:partition])
              when nil
                nil
              else
                @buffer << response
              end

              if @rebalance_manager.changed?
                events_poll
                break
              end

              break if @interval_runner.call == :stop

              time_poll.checkpoint

              break if response.nil? || response.is_a?(Hash)
            end
          end
        end
      end
    end
  end
end
