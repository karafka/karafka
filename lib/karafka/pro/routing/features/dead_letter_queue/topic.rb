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
        class DeadLetterQueue < Base
          # Expansions to the topic API in DLQ
          module Topic
            # This method calls the parent class initializer and then sets up the
            # extra instance variable to nil. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              super
              @dead_letter_queue = nil
            end

            # @param strategy [#call, nil] Strategy we want to use or nil if a default strategy
            # (same as in OSS) should be applied
            # @param args [Hash] Pro DLQ arguments
            # @option args [String, nil] :topic name of the dead letter queue topic
            # @option args [Integer] :max_retries maximum number of retries before dispatch to DLQ
            # @option args [Boolean] :independent whether DLQ runs independently
            def dead_letter_queue(strategy: nil, **args)
              return @dead_letter_queue if @dead_letter_queue

              super(**args).tap do |config|
                # If explicit strategy is not provided, use the default approach from OSS
                config.strategy = strategy || lambda do |_errors_tracker, attempt|
                  (attempt > config.max_retries) ? :dispatch : :retry
                end
              end
            end
          end
        end
      end
    end
  end
end
