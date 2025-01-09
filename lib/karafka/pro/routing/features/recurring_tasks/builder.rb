# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class RecurringTasks < Base
          # Routing extensions for recurring tasks
          module Builder
            # Enabled recurring tasks operations and adds needed topics and other stuff.
            #
            # @param active [Boolean] should recurring tasks be active. We use a boolean flag to
            #   have API consistency in the system, so it matches other routing related APIs.
            # @param block [Proc] optional reconfiguration of the topics definitions.
            def recurring_tasks(active = false, &block)
              return unless active

              # We only require zlib when we decide to run recurring tasks because it is not needed
              # otherwise.
              require 'zlib'
              ensure_fugit_availability!

              tasks_cfg = App.config.recurring_tasks
              topics_cfg = tasks_cfg.topics

              consumer_group tasks_cfg.group_id do
                # Registers the primary topic that we use to control schedules execution. This is
                # the one that we use to trigger recurring tasks.
                schedules_topic = topic(topics_cfg.schedules) do
                  consumer tasks_cfg.consumer_class
                  deserializer tasks_cfg.deserializer
                  # Because the topic method name as well as builder proxy method name is the same
                  # we need to reference it via target directly
                  target.recurring_tasks(true)

                  # We manage offsets directly because messages can have both schedules and
                  # commands and we need to apply them only when we need to
                  manual_offset_management(true)

                  # We use multi-batch operations and in-memory state for schedules. This needs to
                  # always operate without re-creation.
                  consumer_persistence(true)

                  # This needs to be enabled for the eof to work correctly
                  kafka('enable.partition.eof': true, inherit: true)
                  eofed(true)

                  # Favour latency. This is a low traffic topic that only accepts user initiated
                  # low-frequency commands
                  max_messages(1)
                  # Since we always react on the received message, we can block for longer periods
                  # of time
                  max_wait_time(10_000)

                  # Since the execution of particular tasks is isolated and guarded, it should not
                  # leak. This means, that this is to handle errors like schedule version
                  # incompatibility and other errors that will not go away without a redeployment
                  pause_timeout(60 * 1_000)
                  pause_max_timeout(60 * 1_000)

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

                  # If this is the direct schedules redefinition style, we run it
                  # The second one (see end of this method) allows for linear reconfiguration of
                  # both the topics
                  instance_eval(&block) if block && block.arity.zero?
                end

                # This topic is to store logs that we can then inspect either from the admin or via
                # the Web UI
                logs_topic = topic(topics_cfg.logs) do
                  active(false)
                  deserializer tasks_cfg.deserializer
                  target.recurring_tasks(true)

                  # Keep cron logs of executions for a week and after that remove. Week should be
                  # enough and should not produce too much data.
                  config(
                    'cleanup.policy': 'delete',
                    'retention.ms': 604_800_000
                  )
                end

                yield(schedules_topic, logs_topic) if block && block.arity.positive?
              end
            end

            # Checks if fugit is present. If not, will try to require it as it might not have
            # been required but is available. If fails, will crash.
            def ensure_fugit_availability!
              return if Object.const_defined?(:Fugit)

              require 'fugit'
            rescue LoadError
              raise(
                ::Karafka::Errors::DependencyConstraintsError,
                <<~ERROR_MSG
                  Failed to require fugit gem.
                  Add it to your Gemfile, as it is required for the recurring tasks to work.
                ERROR_MSG
              )
            end
          end
        end
      end
    end
  end
end
