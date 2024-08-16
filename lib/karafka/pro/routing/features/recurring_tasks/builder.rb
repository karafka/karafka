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
        class RecurringTasks < Base
          # Routing extensions for recurring tasks
          module Builder
            # Enabled recurring tasks operations and adds needed topics and other stuff.
            #
            # @param block [Proc] optional reconfiguration of the tasks topic definitions.
            # @note Since we cannot provide two blocks, reconfiguration of logs topic can be only
            #   done if user explicitly redefines it in the routing.
            def recurring_tasks(&block)
              tasks_cfg = App.config.recurring_tasks
              topics_cfg = tasks_cfg.topics

              consumer_group tasks_cfg.group_id do
                # Registers the primary topic that we use to control schedules execution. This is
                # the one that we use to trigger recurring tasks.
                topic(topics_cfg.schedules) do
                  consumer tasks_cfg.consumer_class
                  # Because the topic method name as well as builder proxy method name is the same
                  # we need to reference it via target directly
                  target.recurring_tasks(true)

                  # We manage offsets directly because messages can have both schedules and
                  # commands and we need to apply them only when we need to
                  manual_offset_management(true)

                  # This needs to be enabled for the eof to work correctly
                  kafka('enable.partition.eof': true, inherit: true)
                  eofed(true)

                  # Keep older data for a day and compact to the last state available
                  config(
                    'cleanup.policy': 'compact,delete',
                    'retention.ms': 86_400_000
                  )

                  # This is the core of execution. Since we're producers of states, we need a way
                  # to tick without having new data
                  periodic(
                    interval: App.config.recurring_tasks.interval,
                    during_pause: false,
                    during_retry: false
                  )

                  next unless block

                  instance_eval(&block)
                end

                # This topic is to store logs that we can then inspect either from the admin or via
                # the Web UI
                topic(topics_cfg.logs) do
                  active(false)
                  target.recurring_tasks(true)

                  # Keep cron logs of executions for a week and after that remove. Week should be
                  # enough and should not produce too much data.
                  config(
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
