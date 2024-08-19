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
      # Matcher used to check if given command can be applied to a given task.
      class Matcher
        # @param message [Karafka::Messages::Message] message with command
        # @return [Boolean] is this message dedicated to current process and is actionable
        def matches?(task, payload)
          # We only match commands
          return false unless payload[:type] == 'command'

          # * is a wildcard to match all for batch commands
          return false unless payload[:task][:id] == '*' || payload[:task][:id] == task.id

          # Ignore messages that have different schema. This can happen in the middle of
          # upgrades of the framework. We ignore this not to risk compatibility issues
          return false unless payload[:schema_version] == Serializer::SCHEMA_VERSION

          schedule = ::Karafka::Pro::RecurringTasks.schedule

          # If the command was issued to a different version of the schedule than the one we
          # operate on, we ignore such commands to avoid compatibility issues.
          return false if payload[:schedule_version] != schedule.version

          true
        end
      end
    end
  end
end
