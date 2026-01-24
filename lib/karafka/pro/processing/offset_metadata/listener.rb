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
      module OffsetMetadata
        # Keeps track of rebalances and updates the fetcher
        # Since we cache the tpls with metadata, we need to invalidate them on events that would
        # cause changes in the assignments
        class Listener
          # When we start listening we need to register this client in the metadata fetcher, so
          # we have the client related to a given subscription group that we can use in fetcher
          # since fetcher may be used in filtering API and other places outside of the standard
          # consumer flow
          # @param event [Karafka::Core::Monitoring::Event]
          def on_connection_listener_before_fetch_loop(event)
            Fetcher.register event[:client]
          end

          # Invalidates internal cache when assignments change so we can get correct metadata
          # @param event [Karafka::Core::Monitoring::Event]
          def on_rebalance_partitions_assigned(event)
            Fetcher.clear event[:subscription_group]
          end

          # Invalidates internal cache when assignments change so we can get correct metadata
          # @param event [Karafka::Core::Monitoring::Event]
          def on_rebalance_partitions_revoked(event)
            Fetcher.clear event[:subscription_group]
          end
        end
      end
    end
  end
end
