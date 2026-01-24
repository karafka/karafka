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
    # Namespace for Pro routing enhancements
    module Routing
      # Namespace for additional Pro features
      module Features
        # Non Blocking Job is just an alias for LRJ.
        #
        # We however have it as a separate feature because its use-case may vary from LRJ.
        #
        # While LRJ is used mainly for long-running jobs that would take more than max poll
        # interval time, non-blocking can be applied to make sure that we do not wait with polling
        # of different partitions and topics that are subscribed together.
        #
        # This effectively allows for better resources utilization
        #
        # All the underlying code is the same but use-case is different and this should be
        # reflected in the routing, hence this "virtual" feature.
        class NonBlockingJob < Base
        end
      end
    end
  end
end
