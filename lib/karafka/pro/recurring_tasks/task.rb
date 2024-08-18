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
    module RecurringTasks
      # Represents a single recurring task that can be executed when the time comes.
      # Tasks should be lightweight. Anything heavy should be executed by scheduling appropriate
      # jobs here.
      class Task
        # @return [String]
        attr_reader :id

        attr_accessor :previous_time

        attr_reader :cron

        # @param id [String] unique id. If re-used between versions, will replace older occurrence.
        # @param cron [String] cron expression matching this task expected execution times.
        # @param previous_time [Integer, Time] previous time this task was executed. 0 if never.
        # @param enabled [Boolean] should this task be enabled. Users may disable given task
        #   temporarily, this is why we need to know that.
        # @param block [Proc] code to execute.
        def initialize(id:, cron:, previous_time: 0, enabled: true, &block)
          @id = id
          @cron = ::Fugit::Cron.do_parse(cron)
          @previous_time = previous_time
          @start_time = Time.now
          @executable = block
          @enabled = enabled
          @trigger = false
        end

        # Disables this task execution indefinitely
        def disable
          @enabled = false
        end

        # Enables back this task
        def enable
          @enabled = true
        end

        # @return [Boolean] is this an executable task
        def enabled?
          @enabled
        end

        # Triggers the execution of this task at the earliest opportunity
        def trigger
          @trigger = true
        end

        # @return [EtOrbi::EoTime] next execution time
        def next_time
          @cron.next_time(@previous_time.to_i.zero? ? @start_time : @previous_time)
        end

        # @return [Boolean] should we execute this task at this moment in time
        def execute?
          return true if @trigger
          return false unless enabled?

          # Ensure the job is only due if current_time is strictly after the next_time
          # Please note that we can only compare eorbi against time and not the other way around
          next_time <= Time.now
        end

        # Executes the given task and stores the execution time.
        def execute
          @executable.call if @executable
        ensure
          @trigger = false
          @previous_time = Time.now
        end
      end
    end
  end
end
