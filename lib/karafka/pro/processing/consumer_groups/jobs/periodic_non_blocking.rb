# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

module Karafka
  module Pro
    module Processing
      # Pro consumer-group-specific processing components
      module ConsumerGroups
        # Pro jobs
        module Jobs
          # Non-Blocking version of the Periodic job
          # We use this version for LRJ topics for cases where saturated resources would not allow
          # to run this job for extended period of time. Under such scenarios, if we would not use
          # a non-blocking one, we would reach max.poll.interval.ms.
          class PeriodicNonBlocking < Periodic
            self.action = :tick

            # @param args [Array] any arguments accepted by
            #   `::Karafka::Pro::Processing::ConsumerGroups::Jobs::Periodic`
            def initialize(*args)
              super
              @non_blocking = true
            end
          end
        end
      end
    end
  end
end
