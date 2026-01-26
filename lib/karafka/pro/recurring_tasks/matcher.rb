# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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
          return false unless payload[:type] == "command"

          # * is a wildcard to match all for batch commands
          return false unless payload[:task][:id] == "*" || payload[:task][:id] == task.id

          # Ignore messages that have different schema. This can happen in the middle of
          # upgrades of the framework. We ignore this not to risk compatibility issues
          return false unless payload[:schema_version] == Serializer::SCHEMA_VERSION

          true
        end
      end
    end
  end
end
