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
