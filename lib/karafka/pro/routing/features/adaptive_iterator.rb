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
        # Feature that pro-actively monitors remaining time until max poll interval ms and
        # cost of processing of each message in a batch. When there is no more time to process
        # more messages from the batch, it will seek back so we do not reach max poll interval.
        # It can be useful when we reach this once in a while. For a constant long-running jobs,
        # please use the Long-Running Jobs feature instead.
        #
        # It also provides some wrapping over typical operations users do, like stopping if
        # revoked, auto-marking, etc
        class AdaptiveIterator < Base
        end
      end
    end
  end
end
