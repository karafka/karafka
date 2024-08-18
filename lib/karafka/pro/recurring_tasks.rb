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
    # Recurring tasks functionality
    module RecurringTasks
      class << self
        # @return [Schedule, nil] current defined schedule or nil if not defined
        attr_reader :current_schedule

        # Simplified API for schedules definitions
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
          @current_schedule = Schedule.new(version: version)
          @current_schedule.instance_exec(&block)
        end

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
          RecurringTasks::Contracts::Config.new.validate!(config.to_h)
        end
      end
    end
  end
end
