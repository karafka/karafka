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
        class LongRunningJob < Base
          # Long-Running Jobs topic API extensions
          module Topic
            # This method calls the parent class initializer and then sets up the
            # extra instance variable to nil. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              super
              @long_running_job = nil
            end

            # @param active [Boolean] do we want to enable long-running job feature for this topic
            def long_running_job(active = false)
              @long_running_job ||= Config.new(active: active)
            end

            alias long_running long_running_job

            # @return [Boolean] is a given job on a topic a long-running one
            def long_running_job?
              long_running_job.active?
            end

            # @return [Hash] topic with all its native configuration options plus lrj
            def to_h
              super.merge(
                long_running_job: long_running_job.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
