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
    # Namespace for Pro connections related components
    module Connection
      # Namespace for Multiplexing management related components
      module Multiplexing
        # Listener used to connect listeners manager to the lifecycle events that are significant
        # to its operations
        class Listener
          # Initializes the multiplexing listener with the connection manager
          def initialize
            @manager = App.config.internal.connection.manager
          end

          # Triggers connection manage subscription groups details noticing
          #
          # @param event [Karafka::Core::Monitoring::Event] event with statistics
          def on_statistics_emitted(event)
            @manager.notice(
              event[:subscription_group_id],
              event[:statistics]
            )
          end
        end
      end
    end
  end
end
