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
    module Routing
      module Features
        class ScheduledMessages < Base
          # Routing extensions for scheduled messages
          module Builder
            # Enabled scheduled messages operations and adds needed topics and other stuff.
            #
            # @param topics_namespace [String, false] namespace for scheduled messages topics.
            #   Customers can have multiple schedule topics flows to prevent key collisions,
            #   prioritize and do other stuff. `false` if not active.
            # @param block [Proc] optional reconfiguration of the topics definitions.
            # @note Namespace for topics should include the divider as it is not automatically
            #   added.
            def scheduled_messages(topics_namespace: false, &block)
              return unless topics_namespace

              # Load zlib only if user enables scheduled messages
              require 'zlib'

              # We set it to 5 so we have enough space to handle more events. All related topics
              # should have same partition count because we expect similar amount of events in
              # messages and logs topics and we need to have per-partition reporting in the
              # states topic.
              default_partitions = 5
              msg_cfg = App.config.scheduled_messages

              consumer_group msg_cfg.group_id do
                # Registers the primary topic that we use to control schedules execution. This is
                # the one that we use to trigger scheduled messages.
                messages_topic = topic("#{topics_namespace}messages") do
                  instance_eval(&block) if block && block.arity.zero?

                  consumer msg_cfg.consumer_class

                  deserializers(
                    headers: msg_cfg.deserializers.headers
                  )

                  # Because the topic method name as well as builder proxy method name is the same
                  # we need to reference it via target directly
                  target.scheduled_messages(true)

                  # We manage offsets directly because messages can have both schedules and
                  # commands and we need to apply them only when we need to
                  manual_offset_management(true)

                  # We use multi-batch operations and in-memory state for schedules. This needs to
                  # always operate without re-creation.
                  consumer_persistence(true)

                  # This needs to be enabled for the eof to work correctly
                  kafka('enable.partition.eof': true, inherit: true)
                  eofed(true)

                  # Since this is a topic that gets replayed because of schedule management, we do
                  # want to get more data faster during recovery
                  max_messages(10_000)

                  max_wait_time(1_000)

                  # This is a setup that should allow messages to be compacted fairly fast. Since
                  # each dispatched message should be removed via tombstone, they do not have to
                  # be present in the topic for too long.
                  config(
                    partitions: default_partitions,
                    # Will ensure, that after tombstone is present, given scheduled message, that
                    # has been dispatched is removed by Kafka
                    'cleanup.policy': 'compact',
                    # When 10% or more dispatches are done, compact data
                    'min.cleanable.dirty.ratio': 0.1,
                    # Frequent segment rotation to support intense compaction
                    'segment.ms': 3_600_000,
                    'delete.retention.ms': 3_600_000,
                    'segment.bytes': 52_428_800
                  )

                  # This is the core of execution. Since we dispatch data in time intervals, we
                  # need to be able to do this even when no new data is coming
                  periodic(
                    interval: msg_cfg.interval,
                    during_pause: false,
                    during_retry: false
                  )

                  # If this is the direct schedules redefinition style, we run it
                  # The second one (see end of this method) allows for linear reconfiguration of
                  # both the topics
                  instance_eval(&block) if block && block.arity.zero?
                end

                # This topic is to store logs that we can then inspect either from the admin or via
                # the Web UI
                logs_topic = topic("#{topics_namespace}logs") do
                  active(false)
                  target.scheduled_messages(true)

                  # Keep logs of executions for a week and after that remove. Week should be
                  # enough and should not produce too much data.
                  config(
                    partitions: default_partitions,
                    'cleanup.policy': 'delete',
                    'retention.ms': 604_800_000
                  )
                end

                # Holds states of scheduler per each of the partitions since they tick
                # independently. We only hold future statistics not to have to deal with
                # any type of state restoration
                states_topic = topic("#{topics_namespace}states") do
                  active(false)
                  target.scheduled_messages(true)
                  config(
                    partitions: default_partitions,
                    'cleanup.policy': 'compact',
                    'min.cleanable.dirty.ratio': 0.1,
                    'segment.ms': 3_600_000,
                    'delete.retention.ms': 3_600_000,
                    'segment.bytes': 52_428_800
                  )
                  deserializers(
                    payload: msg_cfg.deserializers.payload
                  )
                end

                yield(messages_topic, logs_topic, states_topic) if block && block.arity.positive?
              end
            end
          end
        end
      end
    end
  end
end
