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
        # Offset Metadata Support with a custom deserializer
        class OffsetMetadata < Base
          class << self
            # If needed installs the needed listener and initializes tracker
            #
            # @param _config [Karafka::Core::Configurable::Node] app config
            def post_setup(_config)
              Karafka::App.monitor.subscribe('app.running') do
                # Initialize the tracker prior to becoming multi-threaded
                Karafka::Processing::InlineInsights::Tracker.instance

                # Subscribe to the statistics reports and collect them
                Karafka.monitor.subscribe(
                  Karafka::Pro::Processing::OffsetMetadata::Listener.new
                )
              end
            end
          end
        end
      end
    end
  end
end
