# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    # Recurring tasks functionality
    module RecurringTasks
      class << self
        # @return [Schedule, nil] current defined schedule or nil if not defined
        def schedule
          @schedule || define('0.0.0') {}
        end

        # Simplified API for schedules definitions and validates the tasks data
        #
        # @param version [String]
        # @param block [Proc]
        #
        # @example
        #   Karafka::Pro::RecurringTasks.define('1.0.1') do
        #     schedule(id: 'mailer', cron: '* * * * *') do
        #       MailingJob.perform_async
        #     end
        #   end
        def define(version = '1.0.0', &block)
          @schedule = Schedule.new(version: version)
          @schedule.instance_exec(&block)

          @schedule.each do |task|
            Contracts::Task.new.validate!(
              task.to_h,
              scope: ['recurring_tasks', task.id]
            )
          end

          @schedule
        end

        # Defines nice command methods to dispatch cron requests
        Executor::COMMANDS.each do |command_name|
          class_eval <<~RUBY, __FILE__, __LINE__ + 1
            # @param task_id [String] task to which we want to dispatch command or '*' if to all
            def #{command_name}(task_id)
              Dispatcher.command('#{command_name}', task_id)
            end
          RUBY
        end

        # Below are private APIs

        # Sets up additional config scope, validations and other things
        #
        # @param config [Karafka::Core::Configurable::Node] root node config
        def pre_setup(config)
          # Expand the config with this feature specific stuff
          config.instance_eval do
            setting(:recurring_tasks, default: Setup::Config.config)
          end
        end

        # @param config [Karafka::Core::Configurable::Node] root node config
        def post_setup(config)
          RecurringTasks::Contracts::Config.new.validate!(
            config.to_h,
            scope: %w[config]
          )

          # Published after task is successfully executed
          Karafka.monitor.notifications_bus.register_event('recurring_tasks.task.executed')

          # Initialize empty dummy schedule, so we always have one and so we do not have to
          # deal with a case where there is no schedule
          RecurringTasks.schedule

          # User can disable logging of executions, in which case we don't track them
          return unless Karafka::App.config.recurring_tasks.logging

          Karafka.monitor.subscribe(Listener.new)
        end

        # Basically since we may have custom producers configured that are not the same as the
        # default one, we hold a reference to old pre-fork producer. This means, that when we
        # initialize it again in post-fork, as long as user uses defaults we should re-inherit
        # it from the default config.
        #
        # @param config [Karafka::Core::Configurable::Node]
        # @param pre_fork_producer [WaterDrop::Producer]
        def post_fork(config, pre_fork_producer)
          return unless config.recurring_tasks.producer == pre_fork_producer

          config.recurring_tasks.producer = config.producer
        end
      end
    end
  end
end
