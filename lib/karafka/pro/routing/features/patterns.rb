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
        # Dynamic topics builder feature.
        #
        # Allows you to define patterns in routes that would then automatically subscribe and
        # start consuming new topics.
        #
        # This feature works by injecting a topic that represents a regexp subscription (matcher)
        # that at the same time holds the builder block for full config of a newly detected topic.
        #
        # We inject a virtual topic to hold settings but also to be able to run validations
        # during boot to ensure consistency of the pattern base setup.
        class Patterns < Base
        end
      end
    end
  end
end
