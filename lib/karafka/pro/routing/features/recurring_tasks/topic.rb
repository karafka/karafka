# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class RecurringTasks < Base
          # Topic extensions to be able to check if given topic is a recurring tasks topic
          # Please note, that this applies to both the schedules topics and reports topics
          module Topic
            # This method calls the parent class initializer and then sets up the
            # extra instance variable to nil. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              super
              @recurring_tasks = nil
            end

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
