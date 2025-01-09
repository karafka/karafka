# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module RecurringTasks
      # Matcher used to check if given command can be applied to a given task.
      class Matcher
        # @param task [Karafka::Pro::RecurringTasks::Task]
        # @param payload [Hash] command message payload
        # @return [Boolean] is this message dedicated to current process and is actionable
        def matches?(task, payload)
          # We only match commands
          return false unless payload[:type] == 'command'

          # * is a wildcard to match all for batch commands
          return false unless payload[:task][:id] == '*' || payload[:task][:id] == task.id

          # Ignore messages that have different schema. This can happen in the middle of
          # upgrades of the framework. We ignore this not to risk compatibility issues
          return false unless payload[:schema_version] == Serializer::SCHEMA_VERSION

          true
        end
      end
    end
  end
end
