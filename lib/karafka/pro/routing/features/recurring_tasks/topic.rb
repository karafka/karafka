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
          # Topic extensions to be able to check if given topic is a recurring tasks topic
          # Please note, that this applies to both the schedules topics and reports topics
          module Topic
            # @param active [Boolean] should this topic be considered related to recurring tasks
            def recurring_tasks(active = false)
              @recurring_tasks ||= Config.new(active: active)
            end

            # @return [Boolean] is this an ActiveJob topic
            def recurring_tasks?
              recurring_tasks.active?
            end

            # @return [Hash] topic with all its native configuration options plus active job
            #   namespace settings
            def to_h
              super.merge(
                recurring_tasks: recurring_tasks.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
