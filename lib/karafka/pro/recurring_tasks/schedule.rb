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
      # Represents the current code-context schedule with defined tasks and their cron execution
      # details. Single schedule includes all the information about all the tasks that we have
      # defined and to be executed in a given moment in time.
      class Schedule
        # @return [String]
        attr_reader :version

        # @param version [String] schedule version. In case of usage of versioning it is used to
        #   ensure, that older still active processes do not intercept the assignment to run older
        #   version of the scheduler. It is important to make sure, that this string is comparable.
        def initialize(version:)
          @version = version
          @tasks = {}
        end

        # Adds task into the tasks accumulator
        # @param task [Task]
        # @note In case of multiple tasks with the same id, it will overwrite
        def <<(task)
          @tasks[task.id] = task
        end

        # Iterates over tasks yielding them one after another
        # @param block [Proc] block that will be executed with each task
        def each(&block)
          @tasks.each_value(&block)
        end

        # @param id [String] id of a particular recurring task
        # @return [Task, nil] task with a given id or nil if not found
        def find(id)
          @tasks[id]
        end

        # Allows us to have a nice DSL for defining schedules
        # @param args [Array] attributes accepted by the task initializer
        def schedule(**args, &block)
          self << Task.new(**args, &block)
        end
      end
    end
  end
end
