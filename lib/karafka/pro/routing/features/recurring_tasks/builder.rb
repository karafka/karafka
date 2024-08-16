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
            def recurring_tasks_topic(name, &block)
              topic(name) do
                consumer App.config.internal.active_job.consumer_class
                recurring_tasks true

                # We manage offsets directly because messages can have both schedules and commands
                # and we need to apply them only when we need to
                manual_offset_management(true)
                eofed(true)
                kafka('enable.partition.eof': true)

                next unless block

                instance_eval(&block)
              end
            end
          end
        end
      end
    end
  end
end
