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
      class Serializer
        def call(schedule)
          tasks = {}

          schedule.each do |task|
            tasks[task.id] = {
              id: task.id,
              cron: task.cron.original,
              previous_time: task.previous_time.to_i,
              next_time: task.next_time.to_i,
              enabled: task.enabled?
            }
          end

          Zlib::Deflate.deflate({
            schema_version: '1.0',
            schedule_version: schedule.version,
            type: 'schedule',
            tasks: tasks
          }.to_json)
        end
      end
    end
  end
end
