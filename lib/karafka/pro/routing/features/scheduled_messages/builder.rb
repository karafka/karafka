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
            # @param active [Boolean] should scheduled messages be active. We use a boolean flag to
            #   have API consistency in the system, so it matches other routing related APIs.
            # @param block [Proc] optional reconfiguration of the messages topic definitions.
            # @note Since we cannot provide two blocks, reconfiguration of logs topic can be only
            #   done if user explicitly redefines it in the routing.
            def scheduled_messages(active = false, &block)
              return unless active

              msg_cfg = App.config.scheduled_messages
              topics_cfg = msg_cfg.topics

              consumer_group msg_cfg.group_id do
                # Registers the primary topic that we use to control schedules execution. This is
                # the one that we use to trigger scheduled messages.
                topic(topics_cfg.messages) do
                  instance_eval(&block) if block

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

                  # This is a setup that shoulda allow messages to be compacted fairly fast. Since
                  # each dispatched message should be removed via tombstone, they do not have to
                  # be present in the topic for too long.
                  config(
                    partitions: 10,
                    'cleanup.policy': 'compact',
                    'min.cleanable.dirty.ratio': 0.1,
                    'segment.ms': 3_600_000,
                    'delete.retention.ms': 3_600_000,
                    'segment.bytes': 52_428_800
                  )

                  # Used for tracking some special metadata
                  offset_metadata(
                    deserializer: msg_cfg.deserializers.offset_metadata
                  )

                  # This is the core of execution. Since we dispatch data in time intervals, we
                  # need to be able to do this even when no new data is coming
                  periodic(
                    interval: msg_cfg.interval,
                    during_pause: false,
                    during_retry: false
                  )
                end

                # This topic is to store logs that we can then inspect either from the admin or via
                # the Web UI
                topic(topics_cfg.logs) do
                  active(false)
                  target.scheduled_messages(true)

                  # Keep logs of executions for a week and after that remove. Week should be
                  # enough and should not produce too much data.
                  config(
                    partitions: 10,
                    'cleanup.policy': 'delete',
                    'retention.ms': 604_800_000
                  )
                end
              end
            end
          end
        end
      end
    end
  end
end
