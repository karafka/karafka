# frozen_string_literal: true

module Karafka
  module Connection
    class Client
      module PollingStrategies
        # Polling strategy for standard consumers (enable.partition.eof not set). Uses
        # poll_batch for maximum throughput: collects up to max_messages in one C call per tick.
        #
        # poll_batch returns Array<Message, RdkafkaError> - errors are inline, never raised.
        # We always iterate the full batch so messages from other partitions after an error are
        # not silently dropped. Fatal non-EARLY errors are the only case where we raise: the
        # consumer is dead and no recovery is possible. All other errors are instrumented and
        # skipped - librdkafka has already exhausted its internal retry budget and will continue
        # to recover on subsequent polls, matching the behaviour of the old poll retry loop.
        module Batch
          private

          # @param time_poll [Karafka::TimeTrackers::Poll] poll time tracker
          def batch_poll_inner(time_poll)
            recoverable_error = nil

            loop do
              time_poll.start

              break if time_poll.exceeded?
              break if @buffer.size >= @subscription_group.max_messages

              remaining_capacity = @subscription_group.max_messages - @buffer.size
              poll_tick = [time_poll.remaining, tick_interval].min
              graceful_break = false

              kafka.poll_batch(poll_tick, max_items: remaining_capacity).each do |result|
                unless result.is_a?(Rdkafka::RdkafkaError)
                  @buffer << result
                  next
                end

                case result.code
                when :partition_eof
                  @buffer.eof(result.details[:topic], result.details[:partition])
                when :unknown_topic_or_part, :unknown_topic, :unknown_partition
                  next if @subscription_group.kafka[:"allow.auto.create.topics"]

                  Karafka.monitor.instrument(
                    "error.occurred",
                    caller: self,
                    error: result,
                    type: "connection.client.poll.error"
                  )
                when :max_poll_exceeded, *EARLY_REPORT_ERRORS
                  Karafka.monitor.instrument(
                    "error.occurred",
                    caller: self,
                    error: result,
                    type: "connection.client.poll.error"
                  )
                  graceful_break = true
                else
                  if result.fatal?
                    Karafka.monitor.instrument(
                      "error.occurred",
                      caller: self,
                      error: result,
                      type: "connection.client.poll.error"
                    )
                    raise result
                  end

                  recoverable_error = result
                  Karafka.monitor.instrument(
                    "error.occurred",
                    caller: self,
                    error: result,
                    type: "connection.client.poll.error"
                  )
                end
              end

              @buffer.polled

              if @rebalance_manager.changed?
                events_poll
                break
              end

              if graceful_break
                kafka.poll_batch(tick_interval, max_items: remaining_capacity).each do |result|
                  @buffer << result unless result.is_a?(Rdkafka::RdkafkaError)
                end

                events_poll if @rebalance_manager.changed?

                break
              end

              break if @interval_runner.call == :stop

              time_poll.checkpoint

              break if @buffer.eof?
            end

            @consecutive_errors_tracker.call(recoverable_error, with_messages: !@buffer.empty?)
          end
        end
      end
    end
  end
end
