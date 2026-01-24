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
    module Processing
      module Jobs
        # Job that represents a "ticking" work. Work that we run periodically for the Periodics
        # enabled topics.
        class Periodic < Karafka::Processing::Jobs::Base
          self.action = :tick

          # @param executor [Karafka::Pro::Processing::Executor] pro executor that is suppose to
          #   run a given job
          def initialize(executor)
            @executor = executor
            super()
          end

          # Code executed before we schedule this job
          def before_schedule
            executor.before_schedule_periodic
          end

          # Runs the executor periodic action
          def call
            executor.periodic
          end
        end
      end
    end
  end
end
