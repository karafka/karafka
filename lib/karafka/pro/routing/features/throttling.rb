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
        # Ability to throttle ingestion of data per topic partition
        # Useful when we have fixed limit of things we can process in a given time period without
        # getting into trouble. It can be used for example to:
        #   - make sure we do not insert things to DB too fast
        #   - make sure we do not dispatch HTTP requests to external resources too fast
        #
        # This feature is virtual. It materializes itself via the `Filtering` feature.
        class Throttling < Base
        end
      end
    end
  end
end
