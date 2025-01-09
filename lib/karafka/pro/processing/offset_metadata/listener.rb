# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
